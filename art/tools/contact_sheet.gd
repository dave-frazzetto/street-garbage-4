@tool
extends SceneTree
## Builds one contact sheet from the reference images (or previews) of every asset in art/tools/assets.tsv, so a batch can be
## reviewed at a glance. Run: godot --headless --path . -s res://art/tools/contact_sheet.gd -- [image_0|preview] [out.png]

const CELL: int = 300
const COLUMNS: int = 5


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "image_0"
	var out: String = args[1] if args.size() > 1 else "res://tests/output/contact_sheet.png"
	var dirs: Array[String] = []
	var keys: Array[String] = []
	for line: String in FileAccess.get_file_as_string("res://art/tools/assets.tsv").split("\n"):
		if line.begins_with("#") or line.strip_edges() == "":
			continue
		var cols: PackedStringArray = line.split("\t")
		keys.append(cols[0])
		dirs.append(cols[1])
	var rows: int = ceili(float(keys.size()) / COLUMNS)
	var sheet: Image = Image.create_empty(COLUMNS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.12, 0.14))
	for i: int in keys.size():
		var path: String = "res://art/models/%s/reference/%s.png" % [dirs[i], which]
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			printerr("missing ", path)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var scale: float = float(CELL - 8) / maxf(img.get_width(), img.get_height())
		img.resize(maxi(1, int(img.get_width() * scale)), maxi(1, int(img.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
		var at: Vector2i = Vector2i((i % COLUMNS) * CELL + (CELL - img.get_width()) / 2, (i / COLUMNS) * CELL + (CELL - img.get_height()) / 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
		print("%d %s" % [i, keys[i]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	sheet.save_png(ProjectSettings.globalize_path(out))
	print("DONE contact sheet ", out)
	quit()
