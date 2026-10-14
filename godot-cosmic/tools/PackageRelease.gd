extends SceneTree

var source_files: Array[String] = []

func collect(directory: String) -> void:
	for filename: String in DirAccess.get_files_at(directory):
		if not filename.ends_with(".tmp"):
			source_files.append(directory.path_join(filename))
	for name: String in DirAccess.get_directories_at(directory):
		if name not in [".godot", "builds", "releases", ".git"]:
			collect(directory.path_join(name))

func make_zip(path: String, files: Array[String], prefix: String = "") -> Error:
	var zip: ZIPPacker = ZIPPacker.new()
	var result: Error = zip.open(path)
	if result != OK: return result
	for file: String in files:
		var name: String = prefix + file.trim_prefix("res://")
		if file.ends_with("CosmicSandbox.exe"): name = "CosmicSandbox.exe"
		result = zip.start_file(name)
		if result != OK: zip.close(); return result
		result = zip.write_file(FileAccess.get_file_as_bytes(file))
		if result != OK: zip.close(); return result
		result = zip.close_file()
		if result != OK: zip.close(); return result
	return zip.close()

func _initialize() -> void:
	if not FileAccess.file_exists("res://builds/windows/CosmicSandbox.exe"):
		push_error("Export Windows Desktop to builds/windows/CosmicSandbox.exe first.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://releases")
	collect("res://")
	source_files.sort()
	var source_error: Error = make_zip("res://releases/cosmic-godot-source.zip", source_files, "CosmicSandboxGodot/")
	var windows_files: Array[String] = ["res://builds/windows/CosmicSandbox.exe", "res://README.md", "res://VALIDATION.md", "res://GODOT_LICENSE.txt", "res://GODOT_THIRD_PARTY.txt"]
	var windows_error: Error = make_zip("res://releases/cosmic-godot-windows.zip", windows_files)
	if source_error != OK or windows_error != OK:
		push_error("Packaging failed: " + error_string(source_error) + "; " + error_string(windows_error))
		quit(1)
		return
	var checksums: FileAccess = FileAccess.open("res://releases/SHA256SUMS.txt", FileAccess.WRITE)
	for filename: String in ["cosmic-godot-source.zip", "cosmic-godot-windows.zip"]:
		checksums.store_line(FileAccess.get_sha256("res://releases/"+filename)+"  "+filename)
	checksums.close()
	print("Packaged ",source_files.size()," source files and the Windows executable using native Godot ZIPPacker.")
	quit()
