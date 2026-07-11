class_name BuildPaintDebug
extends RefCounted

## Toggleable build-paint diagnostics (console + optional on-screen label).

static var enabled: bool = true
static var _lines: PackedStringArray = PackedStringArray()
static const MAX_LINES := 10

static var on_log: Callable


static func log(message: String) -> void:
	if not enabled:
		return
	var line := "[BuildPaint] %s" % message
	print(line)
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	if on_log.is_valid():
		on_log.call(get_display_text())


static func get_display_text() -> String:
	return "\n".join(_lines)


static func clear() -> void:
	_lines = PackedStringArray()
	if on_log.is_valid():
		on_log.call("")
