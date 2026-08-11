class_name Loc
## The one place that text becomes the palyer's language.
##
## All text will pass through here.
## Keyed in english for easy writing.
##
## Example :
## await Field.say("Take this, it will help you on your way.")
## presenter.show_message(Loc.line("Wild {pokemon} appeared!", {"pokemon": name}))
##
## Falls back to English not missing keys.
##
## Domains
## Every sentance lives in the main domain, whatever file it was written 
## in so a message can be translated without knowing where it came from.
## The catalogs stay seperate files for the sake of translation, only runtime is shared.
##
## Data record names are the exception, and get a domain per category.
## This is to prevent clashing between categories (such as the 'Psychic' type and the 'Psychic' trianer)
## [method data_domain] builds the domain name for a category so the catalogs, the extractor, and the runtime all agree on it.
##
## Placeholders
## Use named `{placeholder}` instead of positional `%s` so that translations can move word order.

## Prefix for the per-category data domains, e.g. `data/species`
const DATA_DOMAIN_PREFIX: String = "data/"

## Translates [param text] and fills in any `{name}` placeholders.
##
## This is what message sinks call, so plain literals handed to [method Field.say] or similar are already handled.
## Call it directly when you need placeholders, because the substitution has to happen after the translation rather than before it.
##
## Text with no translation comes back unchanged.
static func line(text: String, params: Dictionary = {}) -> String:
	if text.is_empty():
		return text
	return format(TranslationServer.translate(text), params)
	
static func data(category: StringName, text: String) -> String:
	if text.is_empty() or category.is_empty():
		return text
	return String(TranslationServer.get_or_add_domain(data_domain(category)).translate(text))
	
## The translation domain a data category's names live in.
static func data_domain(category: StringName) -> StringName:
	return StringName(DATA_DOMAIN_PREFIX + String(category))
	
## Fills `{name}` style placeholders in [param text] from [param params].
## Seperate for configurability.
static func format(text: String, params: Dictionary) -> String:
	if params.is_empty():
		return text
	return text.format(params)
	
## Translates a list of strings, for choice menus and command lists.
static func lines(texts: Array) -> Array[String]:
	var result: Array[String] = []
	for text: Variant in texts:
		result.append(line(String(text)))
	return result
