shader_type canvas_item;

uniform vec2 centre = vec2(0.5, 0.5);

uniform float radius : hint_range(0.0, 2048.0) = 64.0;

uniform float edge : hint_range(0.0, 1.0) = 0.35;

uniform vec2 rect_size = vec2 (512.0, 384.0);

uniform float darkness : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 offset = (UV - centre) * rect_size;
	float distance_from_centre = length(offset);
	float inner = radius * (1.0 - edge);
	float shade = smoothstep(inner, radius, distance_from_centre);
	COLOR = vec4(0.0, 0.0, 0.0, shade * darkness);
}
