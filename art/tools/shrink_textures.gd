@tool
extends SceneTree
## Shrinks the textures Godot extracts next to each generated GLB (the *_0.png / *_Image_0.png files) to a maximum size, so
## the web build stays small. The camera is far away, so 1024 px is plenty. Run after importing new models, then import again:
## godot --headless --path . -s res://art/tools/shrink_textures.gd -- [max_size]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var limit: int = int(args[0]) if args.size() > 0 else 1024
	var shrunk: int = 0
	for path: String in _pngs("res://art/models"):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null or maxi(img.get_width(), img.get_height()) <= limit:
			continue
		var scale: float = float(limit) / maxi(img.get_width(), img.get_height())
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(path))
		shrunk += 1
		print("shrunk ", path.get_file())
	print("DONE shrink_textures: %d files to max %d" % [shrunk, limit])
	quit()


func _pngs(dir: String) -> Array[String]:
	var found: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		if sub == "reference" or sub == "clips":
			continue
		found.append_array(_pngs(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".png") and (file.contains("_0.png") or file.contains("baseColor") or file.contains("Image_")):
			found.append(dir.path_join(file))
	return found
