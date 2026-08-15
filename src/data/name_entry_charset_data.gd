@tool
class_name NameEntryCharsetData
extends Resource

## Creates a language specific keyboard for input screens.
##
## Because these screens have to be language specific this defines the character sets and they will 
## then be split up and displayed by the screen.

## Locale this keyboard is for by key ( such are &"ru" )
## A full code such as &"pt_BR" is prefered when both exist.
@export var locale: StringName = &"en"

## Characters offered, per page.
## One string per page.
@export var pages: Array[String] = []

## Label for each page's button to switch, in the same order as [member pages]
##
## These are the keys themselves not words, such as 'ABC' and are left out of translation catalogs, so they're translated here instead.
@export var page_names: Array[String] = []

## Characters in a row, in the grid. Adjust for wider characters.
@export_range(4, 16) var columns: int = 9

## Longest name allowed by the language.
## `0` to keep caller default.
@export_range(0, 32) var max_length: int = 0



## Returns `true` when a keyboard can be used
func is_usable() -> bool:
	if pages.is_empty():
		return false
	for page: String in pages:
		if not page.is_empty():
			return true
	return false


## The label for page [param index]
## Falls back to number
func page_name(index: int) -> String:
	if index < page_names.size() and not page_names[index].is_empty():
		return page_names[index]
	return str(index + 1)
