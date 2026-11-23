#!/usr/bin/env bash
# Batch-generates the art in art/tools/assets.tsv with the Meshy CLI (see docs/art/style-guide.md).
# Usage: art/tools/generate_assets.sh images [key...]   text-to-image reference for each asset (cheap), saved under reference/
#        art/tools/generate_assets.sh models [key...]   image-to-3d from those references. Props (kind prop/weapon): standard
#                                                       meshy-7.1 + 4k geometry + meshy-7 PBR, then a remesh to the polycount in
#                                                       the table. Characters (kind char, char_stylised): smart topology + meshy-n1 as before.
#        art/tools/generate_assets.sh get [key...]      download finished models (GLB) next to their references
# Task ids are kept in art/tools/.tasks/<key>.<stage> (gitignored). Needs the meshy CLI and `meshy auth login`.
set -eu
cd "$(dirname "$0")/../.."
STYLE_HQ="$(cat art/tools/style_hq.txt), no text, no logos, no people."
STYLE_PLAYER="$(cat art/tools/style_player.txt)"
W="$(pwd -W 2>/dev/null || pwd)"
TASKS=art/tools/.tasks
mkdir -p "$TASKS"
# Git Bash cannot run the npm shim on Windows: call the CLI through node when MESHY_JS is set, else use `meshy` on PATH.
meshy() { if [ -n "${MESHY_JS:-}" ]; then node "$MESHY_JS" "$@"; else command meshy "$@"; fi; }
stage="${1:?usage: images|models|get [key...]}"
shift || true
want=" $* "

rows() {
  grep -v '^#' art/tools/assets.tsv | while IFS=$'\t' read -r key dir kind aspect tris tex prompt; do
    if [ "$want" != "  " ] && [[ "$want" != *" $key "* ]]; then continue; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$key" "$dir" "$kind" "$aspect" "$tris" "$tex" "$prompt"
  done
}
tid() { grep -m1 '"task_id"' | grep -oE '[0-9a-f-]{36}'; }
failed() { grep -E '"status": "(FAILED|CANCELED)"'; }

case "$stage" in
images)
  rows | while IFS=$'\t' read -r key dir kind aspect tris tex prompt; do
    style="$STYLE_HQ"; [ "$kind" = char_stylised ] && style="$STYLE_PLAYER"
    id=$(meshy text-to-image create --ai-model gpt-image-2-5-flare --prompt "$prompt. $style" --aspect-ratio "$aspect" --async --format json --no-update-check | tid)
    echo "$id" > "$TASKS/$key.image"
    echo "submitted image $key $id"
  done
  rows | while IFS=$'\t' read -r key dir kind aspect tris tex prompt; do
    id=$(cat "$TASKS/$key.image")
    mkdir -p "art/models/$dir/reference"
    meshy text-to-image wait "$id" --timeout 600 --format json --no-update-check | failed && echo "FAILED $key" || true
    meshy download --resource text-to-image --task-id "$id" --kind image --overwrite --output-dir "art/models/$dir/reference" --workspace "$W" --format json --no-update-check | grep -q '"state": "completed"' && echo "image ok $key"
  done ;;
models)
  rows | while IFS=$'\t' read -r key dir kind aspect tris tex prompt; do
    img=$(cat "$TASKS/$key.image")
    pose=""; [ "$kind" = char ] && pose="--pose-mode a-pose"
    if [ "$kind" = char_stylised ]; then
      # the stylised player: clean smart topology and a flat base-colour texture (cel-shaded look)
      id=$(meshy image-to-3d create --input-task-id "$img" --model-type smart-topology --ai-model meshy-t2.5 --pose-mode a-pose --target-polycount "$tris" --texture-model meshy-n1 --target-formats glb --async --format json --no-update-check | tid)
    else
      id=$(meshy image-to-3d create --input-task-id "$img" --model-type standard --geometry-resolution 4k --should-texture true --texture-model meshy-7 --enable-pbr true --texture-resolution "$tex" $pose --target-formats glb --async --format json --no-update-check | tid)
    fi
    echo "$id" > "$TASKS/$key.model"
    echo "submitted model $key $id"
  done
  rows | while IFS=$'\t' read -r key dir kind aspect tris tex prompt; do
    id=$(cat "$TASKS/$key.model")
    meshy image-to-3d wait "$id" --timeout 1800 --format json --no-update-check | failed && echo "FAILED $key" || true
    if [ "$kind" != char_stylised ]; then
      rid=$(meshy remesh create --input-task-id "$id" --topology triangle --target-polycount "$tris" --target-formats glb --async --format json --no-update-check | tid)
      echo "$rid" > "$TASKS/$key.remesh"
      echo "submitted remesh $key $rid"
    fi
  done
  rows | while IFS=$'\t' read -r key dir kind aspect tris tex prompt; do
    if [ -f "$TASKS/$key.remesh" ]; then
      meshy remesh wait "$(cat "$TASKS/$key.remesh")" --timeout 1800 --format json --no-update-check | failed && echo "FAILED remesh $key" || true
    fi
  done ;;
get)
  rows | while IFS=$'\t' read -r key dir kind aspect tris tex prompt; do
    name=$(basename "$dir")
    rm -f "art/models/$dir/$name.glb" "art/models/$dir/${name}_meta.json"
    if [ -f "$TASKS/$key.remesh" ]; then res=remesh; id=$(cat "$TASKS/$key.remesh"); else res=image-to-3d; id=$(cat "$TASKS/$key.model"); fi
    meshy $res get "$id" -o "art/models/$dir/$name.glb" --workspace "$W" --format json --no-update-check | grep -q '"state": "completed"' && echo "model ok $key"
    meshy download --resource image-to-3d --task-id "$(cat "$TASKS/$key.model")" --asset thumbnail.primary --overwrite --output "art/models/$dir/reference/preview.png" --workspace "$W" --format json --no-update-check > /dev/null || true
  done ;;
*) echo "usage: $0 images|models|get [key...]"; exit 2 ;;
esac
