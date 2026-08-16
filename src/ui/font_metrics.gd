class_name FontMetrics
extends RefCounted
## Adds room for descenders to fonts with incomplete metrics.

## Some fonts report a zero descender at every size.
## Measures glyph outlines and stores the result in the font's size cache.
## Other font properties are left unchanged.

## FontMetrics.repair_descent(skin.main_font, 22)

## Fonts with correct metrics are left unchanged.

## Characters used to measure the font's lowest glyph outlines.
const DESCENDING: String = "gjpqy,;()[]{}/\\Q$_"

## Gives [param font] enough room for descenders at [param font_size].

## The correction is applied only to [FontFile] resources and is stored per font size.
static func repair_descent(font: Font, font_size: int) -> void:
	var file: FontFile = font as FontFile
	if file == null or font_size <= 0:
		return
	var needed: float = ink_descent(file, font_size)
	if needed <= file.get_descent(font_size):
		return
	for index: int in range(maxi(file.get_cache_count(), 1)):
		file.set_cache_descent(index, font_size, needed)

## Returns how far [param font]'s glyphs extend below the baseline at [param font_size].

## The value is measured from the rasterised outlines rather than the font metrics.
static func ink_descent(font: Font, font_size: int) -> float:
	if font == null or font_size <= 0:
		return 0.0
	var server: TextServer = TextServerManager.get_primary_interface()
	if server == null:
		return 0.0
	var key: Vector2i = Vector2i(font_size, 0)
	var deepest: float = 0.0
	for rid: RID in font.get_rids():
		for index: int in range(DESCENDING.length()):
			var glyph: int = server.font_get_glyph_index(
				rid, font_size, DESCENDING.unicode_at(index), 0
			)
			if glyph == 0:
				continue
			var offset: Vector2 = server.font_get_glyph_offset(rid, key, glyph)
			var glyph_size: Vector2 = server.font_get_glyph_size(rid, key, glyph)
			deepest = maxf(deepest, offset.y + glyph_size.y)
	return deepest
