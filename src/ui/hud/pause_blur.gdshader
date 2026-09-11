shader_type canvas_item;
// 暂停菜单背景模糊遮罩 shader（GAP-4 裁决——设计来源 design/ux/pause-menu.md
// 「半透明黑色遮罩 + 背景模糊」+ interaction-patterns.md「遮罩层」）。
// 采样自 BACKBUFFER（BackBufferCopy 提供——先例 L199），Downsample + Box blur。
// uniform 纹理类型用 Texture 基类型（4.4+ 变更——见 control-manifest 禁止模式）。
uniform sampler2D screen_tex : source_color, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;
uniform int blur_radius : hint_range(1, 8) = 4;
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);

void fragment() {
	vec4 blurred = vec4(0.0);
	float total = 0.0;
	// 简化双重环形 Box blur：性能友好（半径 ≤8 × 环 16 采样），静态 Pass 下帧预算内
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 0.3926991; // 2π/16
		vec2 offs = vec2(cos(angle), sin(angle)) * float(blur_radius) * SCREEN_PIXEL_SIZE;
		blurred += texture(screen_tex, SCREEN_UV + offs);
		blurred += texture(screen_tex, SCREEN_UV + offs * 0.5);
		total += 2.0;
	}
	blurred /= total;
	// 模糊强度插值 + 60% alpha 半透明黑叠加（dim_color.a = 0.6）
	vec3 mixed = mix(texture(screen_tex, SCREEN_UV).rgb, blurred.rgb, blur_amount);
	COLOR = vec4(mixed, dim_color.a);
}
