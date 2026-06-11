shader_type canvas_item;
// CRT 半透明オーバーレイ（style.css の .scanlines / .screen-vignette / .screen-glass-curve 相当）
// 画面内容は変えず、暗線・ビネット・ガラス反射だけを alpha ブレンドで重ねる

uniform float effect_strength: hint_range(0.0, 1.0) = 1.0;
uniform float scanline_alpha: hint_range(0.0, 1.0) = 0.25;
uniform float scanline_density: hint_range(60.0, 480.0) = 120.0;
uniform float vignette_strength: hint_range(0.0, 2.0) = 0.85;

void fragment() {
	vec2 uv = UV;
	float strength = effect_strength;

	// --- スキャンライン（半透明の黒線） ---
	float dark_alpha = 0.0;
	if (mod(uv.y * scanline_density, 2.0) < 1.0) {
		dark_alpha = scanline_alpha * strength;
	}

	// --- ビネット（四隅を inset shadow 風に暗く） ---
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig = dot(vig_uv, vig_uv);
	dark_alpha = max(dark_alpha, smoothstep(0.35, 1.4, vig) * vignette_strength * 0.55 * strength);

	// --- 曲面ガラス反射（上部に薄い白ハイライト） ---
	float glass_alpha = max(0.0, 1.0 - abs(uv.x - 0.5) * 3.0) * (1.0 - uv.y) * 0.12 * strength;

	// ハイライト優先（中央上部はビネットが弱いため干渉しにくい）
	if (glass_alpha > dark_alpha) {
		COLOR = vec4(1.0, 1.0, 1.0, glass_alpha);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, dark_alpha);
	}
}
