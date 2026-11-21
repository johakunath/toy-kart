extends SceneTree
## Loads every script, scene and resource of the project once and fails on any error.
##
##   godot --headless --path . --script res://tools/parse_check.gd
##
## Exit code 0 = everything loads. Used by tools/check.ps1.

const SKIP_DIRS := [".godot", "builds", "photos", "docs", "licenses", ".git"]

var _failed: Array[String] = []
var _count := 0

## The scan runs on the first frame, not in _init: autoloads (Game) only exist by then.
func _process(_delta: float) -> bool:
	_scan("res://")
	if _failed.is_empty():
		print("PARSE CHECK: PASS (%d files)" % _count)
		quit(0)
	else:
		for path in _failed:
			print("PARSE CHECK: could not load ", path)
		print("PARSE CHECK: FAIL (%d of %d files)" % [_failed.size(), _count])
		quit(1)
	return true

func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub in SKIP_DIRS or sub.begins_with("."):
			continue
		_scan(dir_path.path_join(sub))
	for file in dir.get_files():
		var ext := file.get_extension()
		if ext not in ["gd", "tscn", "tres"]:
			continue
		var path := dir_path.path_join(file)
		if path.contains("/kenney_racing/models/Library/mesh-library.tscn"):
			continue  # kit helper scene, references a model the kit does not ship
		_count += 1
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			_failed.append(path)
		elif res is GDScript and not (res as GDScript).can_instantiate():
			_failed.append(path)
