extends RefCounted

static func load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_warning("Data file not found: %s" % path)
        return {}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Unable to open data file: %s" % path)
        return {}

    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    push_warning("Data file is not a JSON object: %s" % path)
    return {}
