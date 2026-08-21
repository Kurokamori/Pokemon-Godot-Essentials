shader_type canvas_item;

uniform float bush_depth = 0.0;

uniform float frame_top = 0.0;

uniform float frame_height = 32.0;

uniform float sheet_height = 32.0;

uniform float bush_opacity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	if (bush_depth > 0.0 && frame_height > 0.0 && sheet_height > 0.0) {
		float depth = (UV.y * sheet_height) - frame_top;
		if (depth > frame_height - bush_depth) {
			COLOR.a *= bush_opacity;
		}
	}
}
