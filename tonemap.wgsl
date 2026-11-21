// A gentle display-space grade: saturation, a soft shoulder that leaves paper white alone, a
// light vignette, then Horizon's own HDR curve so highlights still fit the display. It reads no
// `previous`, so the game keeps FXAA/TAA.

override final_saturation_enabled: bool = true;
override final_contrast_enabled: bool = true;
override soft_shoulder_enabled: bool = true;
override vignette_enabled: bool = true;
override saturation: f32 = 1.12;
override contrast: f32 = 1.04;
override vignette: f32 = 0.22;

fn tonemap(input: TonemapInput) -> vec3<f32> {
    var c = max(input.color, vec3<f32>(0.0));
    var g = pow(c, vec3<f32>(1.0 / 2.2));

    if final_saturation_enabled && ab_preset_at_least(PRESET_LOW) {
        let grey = dot(g, frame.luminance);
        g = mix(vec3<f32>(grey), g, saturation);
    }
    if final_contrast_enabled && ab_preset_at_least(PRESET_LOW) {
        g = (g - vec3<f32>(0.5)) * contrast + vec3<f32>(0.5);
    }
    if soft_shoulder_enabled && ab_preset_at_least(PRESET_LOW) {
        g = g / (vec3<f32>(1.0) + 0.12 * g) * 1.12;
    }

    if vignette_enabled && ab_preset_at_least(PRESET_NORMAL) && vignette > 0.0 {
        let aspect = frame.resolution.x / frame.resolution.y;
        let d = length((input.uv - vec2<f32>(0.5)) * vec2<f32>(aspect, 1.0))
              / length(vec2<f32>(aspect, 1.0) * 0.5);
        g *= vec3<f32>(1.0 - smoothstep(0.55, 1.1, d) * vignette);
    }

    c = pow(max(g, vec3<f32>(0.0)), vec3<f32>(2.2));
    if frame.hdr != 0u {
        let top = max(c.r, max(c.g, c.b));
        c *= ab_tone_scale(top, frame.headroom, frame.paper_white);
    }
    return min(c, vec3<f32>(frame.headroom));
}
