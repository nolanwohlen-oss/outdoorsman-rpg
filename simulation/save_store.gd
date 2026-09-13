extends RefCounted
## Versioned local save slots. Verify temporary bytes, then replace atomically.

const World = preload("res://simulation/world_state.gd")
const SAVE_VERSION := 1
const MAX_BYTES := 1048576
const DEFAULT_DIRECTORY := "user://saves"
var directory: String

func _init(save_directory: String = DEFAULT_DIRECTORY) -> void:
	directory = save_directory

static func payload_text(record: Dictionary) -> String:
	return JSON.stringify(record, "", true, true)

static func fingerprint(record: Dictionary) -> String:
	return payload_text(record).sha256_text()

static func encode(record: Dictionary) -> String:
	var payload := payload_text(record)
	return JSON.stringify({"format": "outdoorsman-save", "save_version": SAVE_VERSION, "payload": payload, "sha256": payload.sha256_text()})

static func _failure(message: String, code: String = "invalid") -> Dictionary:
	return {"ok": false, "message": message, "code": code}

static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("Save exceeds the file size limit.")
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _failure("Save is not valid JSON.")
	var envelope: Dictionary = parser.data
	if envelope.get("format") == "outdoorsman-save" and World.is_integer(envelope.get("save_version"), 1, World.MAX_TIME_MS) and envelope.save_version != SAVE_VERSION:
		return _failure("Unsupported save version; existing files were kept.", "unsupported")
	if not World.has_keys(envelope, ["format", "save_version", "payload", "sha256"]) or envelope.format != "outdoorsman-save" or not World.is_integer(envelope.save_version, SAVE_VERSION, SAVE_VERSION):
		return _failure("Save envelope is invalid.")
	if not envelope.payload is String or not envelope.sha256 is String or envelope.sha256.length() != 64 or envelope.payload.sha256_text() != envelope.sha256:
		return _failure("Save checksum does not match.")
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary:
		return _failure("World payload is invalid JSON.")
	var migration := World.migrate_record(parser.data)
	if not migration.ok:
		return _failure(migration.message, migration.get("code", "invalid"))
	return {"ok": true, "record": World.from_record(migration.record).to_record(), "migrated": migration.get("migrated", false), "message": migration.get("message", "Saved world restored exactly. Clock paused.")}

func path_for(slot: String) -> String:
	return directory.path_join(slot + ".json")

func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot)) or FileAccess.file_exists(path_for(slot) + ".bak")

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("No save in this slot.", "missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Cannot open save: %s." % error_string(FileAccess.get_open_error()), "io")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _failure("Save exceeds the file size limit.")
	var text := file.get_as_text()
	file.close()
	return decode(text)

func load_slot(slot: String) -> Dictionary:
	if not slot in ["manual", "autosave"]:
		return _failure("Unknown save slot.")
	var primary := _read(path_for(slot))
	if primary.ok:
		primary.recovered = false
		return primary
	# Do not silently downgrade a newer save or substitute an older run.
	if primary.code == "unsupported":
		return primary
	var backup := _read(path_for(slot) + ".bak")
	if not backup.ok and backup.code == "unsupported":
		return backup
	if backup.ok:
		backup.recovered = true
		backup.message = "Recovered the previous valid backup; its progress may be older."
		return backup
	return _failure(primary.message + " No valid backup available.", primary.code)

func _write(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var result := file.get_error()
	file.close()
	return result

func save_slot(slot: String, record: Dictionary, allow_replace_unsupported: bool = false) -> Dictionary:
	if not slot in ["manual", "autosave"]:
		return _failure("Unknown save slot.")
	var errors := World.validate(record)
	if not errors.is_empty():
		return _failure("Save rejected: " + " ".join(errors))
	var make_dir := DirAccess.make_dir_recursive_absolute(directory)
	if make_dir != OK:
		return _failure("Cannot create save directory: " + error_string(make_dir), "io")
	var primary := path_for(slot)
	var previous := _read(primary)
	if not previous.ok and previous.code == "unsupported" and not allow_replace_unsupported:
		return previous
	if not previous.ok and not allow_replace_unsupported:
		var backup := _read(primary + ".bak")
		if not backup.ok and backup.code == "unsupported":
			return backup
	var temporary := primary + ".tmp"
	var result := _write(temporary, encode(record))
	if result != OK:
		return _failure("Cannot write save: " + error_string(result), "io")
	var verified := _read(temporary)
	if not verified.ok or fingerprint(verified.record) != fingerprint(record):
		return _failure("Temporary save verification failed; previous save was kept.", "io")
	# Never promote a corrupt primary over a good backup.
	if previous.ok:
		result = DirAccess.copy_absolute(primary, primary + ".bak.tmp")
		if result != OK or not _read(primary + ".bak.tmp").ok:
			return _failure("Could not preserve the previous save.", "io")
		result = DirAccess.rename_absolute(primary + ".bak.tmp", primary + ".bak")
		if result != OK:
			return _failure("Could not replace the save backup.", "io")
	result = DirAccess.rename_absolute(temporary, primary)
	if result != OK:
		return _failure("Could not replace the save; previous save was kept.", "io")
	return {"ok": true, "message": "Saved.", "fingerprint": fingerprint(record)}
