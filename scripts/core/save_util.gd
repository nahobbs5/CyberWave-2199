class_name SaveUtil
extends RefCounted
## Crash-safe file writes (GDD 13.2): write a temporary file, then swap it in,
## so a crash mid-write never leaves a half-written save.


static func write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't write %s" % tmp)
		return false
	file.store_string(text)
	file.close()
	var dest := ProjectSettings.globalize_path(path)
	var src := ProjectSettings.globalize_path(tmp)
	if DirAccess.rename_absolute(src, dest) == OK:
		return true
	# Some platforms won't rename over an existing file.
	DirAccess.remove_absolute(dest)
	return DirAccess.rename_absolute(src, dest) == OK


## Reads a save, falling back to the temporary file if a swap was interrupted.
static func read_text(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	if FileAccess.file_exists(path + ".tmp"):
		return FileAccess.get_file_as_string(path + ".tmp")
	return ""


static func remove(path: String) -> void:
	for p in [path, path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
