#!/usr/bin/env bash
# Batch-generates the art in art/tools/assets.tsv with the Meshy CLI (see docs/art/style-guide.md).
# Usage: art/tools/generate_assets.sh images [key...]   text-to-image reference for each asset (cheap), saved under reference/
#        art/tools/generate_assets.sh models [key...]   image-to-3d from those references, GLB saved next to them
# Task ids are kept in art/tools/.tasks/<key>.<stage> (gitignored). Needs the meshy CLI on PATH and `meshy auth login`.
set -eu
cd "$(dirname "$0")/../.."
STYLE="Gritty cyberpunk dark-horror stylised realism, chunky exaggerated proportions, strong readable silhouette, hand-painted PBR textures, desaturated dirty palette with a single neon accent colour (magenta, cyan or orange), worn metal and leather, chrome and circuitry details, no text, no logos."
W="$(pwd -W 2>/dev/null || pwd)"
TASKS=art/tools/.tasks
mkdir -p "$TASKS"
stage="${1:?usage: images|models [key...]}"
shift || true
want=" $* "

rows() {
  grep -v '^#' art/tools/assets.tsv | while IFS=$'\t' read -r key dir kind aspect tris prompt; do
    if [ "$want" != "  " ] && [[ "$want" != *" $key "* ]]; then continue; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$key" "$dir" "$kind" "$aspect" "$tris" "$prompt"
  done
}
tid() { grep -m1 '"task_id"' | grep -oE '[0-9a-f-]{36}'; }

case "$stage" in
images)
  rows | while IFS=$'\t' read -r key dir kind aspect tris prompt; do
    id=$(meshy text-to-image create --ai-model gpt-image-2-5-flare --prompt "$prompt. $STYLE" --aspect-ratio "$aspect" --async --format json --no-update-check | tid)
    echo "$id" > "$TASKS/$key.image"
    echo "submitted image $key $id"
  done
  rows | while IFS=$'\t' read -r key dir kind aspect tris prompt; do
    id=$(cat "$TASKS/$key.image")
    mkdir -p "art/models/$dir/reference"
    meshy text-to-image wait "$id" --timeout 600 --format json --no-update-check | grep -E '"status": "(FAILED|CANCELED)"' && echo "FAILED $key" || true
    meshy download --resource text-to-image --task-id "$id" --kind image --overwrite --output-dir "art/models/$dir/reference" --workspace "$W" --format json --no-update-check | grep -q '"state": "completed"' && echo "image ok $key"
  done ;;
models)
  rows | while IFS=$'\t' read -r key dir kind aspect tris prompt; do
    img=$(cat "$TASKS/$key.image")
    if [ "$kind" = char ]; then extra="--ai-model meshy-t2.5 --pose-mode a-pose"; else extra="--ai-model meshy-t2"; fi
    id=$(meshy image-to-3d create --input-task-id "$img" --model-type smart-topology $extra --target-polycount "$tris" --texture-model meshy-n1 --target-formats glb --async --format json --no-update-check | tid)
    echo "$id" > "$TASKS/$key.model"
    echo "submitted model $key $id"
  done
  rows | while IFS=$'\t' read -r key dir kind aspect tris prompt; do
    id=$(cat "$TASKS/$key.model")
    meshy image-to-3d wait "$id" --timeout 900 --format json --no-update-check | grep -E '"status": "(FAILED|CANCELED)"' && echo "FAILED $key" || true
    name=$(basename "$dir")
    rm -f "art/models/$dir/$name.glb" "art/models/$dir/${name}_meta.json"
    meshy image-to-3d get "$id" -o "art/models/$dir/$name.glb" --workspace "$W" --format json --no-update-check | grep -q '"state": "completed"' && echo "model ok $key"
    meshy download --resource image-to-3d --task-id "$id" --asset thumbnail.primary --overwrite --output "art/models/$dir/reference/preview.png" --workspace "$W" --format json --no-update-check > /dev/null || true
  done ;;
*) echo "usage: $0 images|models [key...]"; exit 2 ;;
esac
