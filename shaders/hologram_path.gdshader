shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// UV convention: UV.x = metres along path (0 at stand), UV.y = 0 left edge / 1 right edge

uniform vec4  color        : source_color  = vec4(0.0, 0.78, 1.0, 1.0);
uniform float scroll_speed : hint_range(0.1, 6.0) = 1.4;
uniform float chevron_size : hint_range(0.2, 3.0) = 0.7;  // metres per repeat
uniform float fill_ratio   : hint_range(0.1, 0.9) = 0.55; // fraction of period that is lit
uniform float edge_power   : hint_range(0.5, 4.0) = 1.8;  // edge fade sharpness
uniform float base_glow    : hint_range(0.0, 0.4) = 0.10; // always-on faint centre line

void fragment() {
	// 0 at ribbon centre, 1 at either edge
	float v_sym = abs(UV.y - 0.5) * 2.0;

	// Soft edge — falls off toward ribbon sides
	float edge = pow(1.0 - v_sym, edge_power);

	// Offset U by lateral distance from centre to produce ">" shape:
	// the tip (v_sym=0) leads, the edges trail by half a chevron period.
	float lateral_offset = v_sym * chevron_size * 0.5;
	float u_phase = fract((UV.x + lateral_offset - TIME * scroll_speed) / chevron_size);

	// Everything inside [0, fill_ratio) is the lit body of the chevron.
	// Gradient: full brightness at the leading edge (u_phase=0), zero at the tail.
	float in_body   = step(u_phase, fill_ratio);
	float gradient  = 1.0 - (u_phase / max(fill_ratio, 0.001));
	float chevron   = in_body * gradient;

	// Faint always-on line so the full route stays readable between chevrons
	float glow = base_glow * edge;

	float alpha = max(glow, chevron * edge);

	ALBEDO = color.rgb;
	ALPHA  = alpha * color.a;
}
