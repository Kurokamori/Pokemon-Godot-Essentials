@tool
class_name EventScript
extends Resource


## The purpose of this is to allow scripts to be written and parsed as scripts rather than command lists.
## This does not replace command lists, and visual scripting will be allowed through the editor, but
## this provides users with a way to write the scripts in plain scripted text that is then interpretted and ran.
##
## The text here is plain text scripting, and will be parsed by [EventScriptParser] then run by [EventScriptRunner].
## It can live in any of three places, and will all end up being consumed the same way :
##
## res://game/scripts/[name].evt -- a file set on the event as a Script File.
## an inline block -- typed into the event as a Script Source
## a .tres of this resource -- for anything that wishes to be a real resource.
## 
## .evt will hopefully be supported with syntax highlighting which will likely make it the prefered option.
##
## A script is read once and then kept, so talking to the same event twice does not re-parse.
## In the editor the file is re-read when it changes on disk, so saving it is enough to see changes.


## What the script says.
## Editable in the inspector for scripts written on the node itself;
## Filled in from disk for scripts kept on file.
@export_multiline var source: String = "":
	set(value):
		if source == value:
			return
		source = value
		_compiled = null
		emit_changed()
		
## What warnings call this script.
## A file path for a script read from disk, or the name of the node the text is written on.
@export var source_name: String = "":
	set(value):
		if source_name == value:
			return
		source_name = value
		_compiled = null
		
const TEXT_EXTENSIONS: PackedStringArray = ["evt", "txt", "script"]

var _compiled: EventScriptProgram = null

## Scripts already read from disk, keyed by path, so even a large map of NPCs sharing a script is only read once.
static var _file_cache: Dictionary = {}

## When each chaced file was last writen, so the editor picks up edits without a restart.
static var _file_stamps: Dictionary = {}


## The parsed program, compiled on first use and then kept afterwards.
##
## TODO: Test if there's a point at which we're storing too much // if this is inefficient.
##
## Parse errors are written out here rather than when the script runs
## This allows say a typo to report itself when the map loads and names the line it's on.
func program() -> EventScriptProgram:
	if _compiled != null:
		return _compiled
	## TODO: Actually create the event script parser.
	_compiled = EventScriptParser.parse(source, _display_name())
	_compiled.report_errors()
	return _compiled
	
## Throws away the parsed program so that the enext run reads the text again.
## Used by the editor when a script file changes under it.
func invalidate() -> void:
	_compiled = null
	
## `true` ehn there is nothing to run.
func is_blank() -> bool:
	if source.strip_edges().is_empty():
		return true
	return program().is_empty()
	
func _display_name() -> String:
	if not source_name.is_empty():
		return source_name
	if not resource_path.is_empty():
		return resource_path
	return "event script"
	
## === Loading ===

## Reads the script at [param path].
## Returns `null` when there's nothing there.
static func load_script(path: String) -> EventScript:
	if path.is_empty():
		return null
	var full: String = path if path.contains("://") else "res://" + path.trim_prefix("/")
	if not TEXT_EXTENSIONS.has(full.get_extension().to_lower()):
		return load(full) as EventScript if ResourceLoader.exists(full) else null
	
	var stamp: int = _modified_time(full)
	if _file_cache.has(full) and int(_file_stamps.get(full, 0)) == stamp:
		return _file_cache[full]
		
	var handle: FileAccess = FileAccess.open(full, FileAccess.READ)
	if handle == null:
		push_error("EventScript: there is no script file at %s." % full)
		_file_cache.erase(full)
		return null
	
	var script: EventScript = EventScript.new()
	script.source_name = full
	script.source = handle.get_as_text()
	handle.close()
	_file_cache[full] = script
	_file_stamps[full] = stamp
	return script
	
## Works out the script that an event or an event page is carrying.
##
## A file takes presedence over text typed onto the node.
## [param cached] is whatever the caller was given last time:
## inline text is only re-read when it has actually changed, and a file manages itself.
static func resolve(file_path: String, inline_source: String, owner_name: String, cached: EventScript) -> EventScript:
		if not file_path.is_empty():
			return load_script(file_path)
		if inline_source.strip_edges().is_empty():
			return null
		if cached != null and cached.source == inline_source:
			return cached
		return from_text(inline_source, owner_name)
		
## Builds a script from text that is not on disk -- an inline block on an event, or a test.
static func from_text(text: String, name: String = "") -> EventScript:
	var script: EventScript = EventScript.new()
	script.source_name = name
	script.source = text
	return script
	
## Forgets every script read from disk.
## Called on project reload, not need by the game.
static func clear_cache() -> void:
	_file_cache.clear()
	_file_stamps.clear()
	
static func _modified_time(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return int(FileAccess.get_modified_time(path))
