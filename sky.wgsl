override sky_tint: bool = true;
override sun_glow_enabled: bool = true;
override moon_glow_enabled: bool = true;
override stars_enabled: bool = true;
override luceros_enabled: bool = true;
override aurora_enabled: bool = true;
override sun_glow: f32 = 0.55;
override aurora_strength: f32 = 0.75;
override star_density: f32 = 1.0;
override lucero_strength: f32 = 1.0;

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    let day = ab_day();
    let night = ab_night();
    let clear = 1.0 - clamp(frame.rain, 0.0, 1.0);
    let h = clamp(d.y, -1.0, 1.0);
    let horizon = 1.0 - smoothstep(0.0, 0.45, abs(h));
    let zenith = smoothstep(0.1, 1.0, h);

    var color = input.color.rgb;
    if sky_tint && ab_preset_at_least(PRESET_LOW) {
        color *= mix(vec3<f32>(0.46, 0.50, 0.78), vec3<f32>(0.88, 0.96, 1.10), day);
        color += vec3<f32>(0.04, 0.015, 0.075) * zenith * night * clear;
        color += vec3<f32>(0.18, 0.055, 0.02) * horizon * day * clear;
    }

    if sun_glow_enabled && ab_preset_at_least(PRESET_LOW) {
        let toward_sun = max(dot(d, frame.sun_direction), 0.0);
        let low_sun = 1.0 - smoothstep(0.0, 0.35, abs(frame.sun_direction.y));
        color += vec3<f32>(1.0, 0.32, 0.07) * pow(toward_sun, 8.0) * (0.25 + 0.75 * low_sun) * day * clear * sun_glow;
    }

    if moon_glow_enabled && ab_preset_at_least(PRESET_LOW) {
        let toward_moon = max(dot(d, frame.moon_direction), 0.0);
        color += vec3<f32>(0.18, 0.24, 0.48) * pow(toward_moon, 16.0) * night * clear;
    }

    // The cell is shared by stars and luceros; skip the hash when both effects are off.
    let want_stars = stars_enabled && ab_preset_at_least(PRESET_NORMAL);
    let want_luceros = luceros_enabled && ab_preset_at_least(PRESET_ENHANCED);
    if want_stars || want_luceros {
        let cell = vec3<i32>(floor(d * 220.0));
        let hash = ab_hash(cell);
        let density = u32(round(star_density));

        if want_stars {
            let star = select(0.0, 1.0, hash % 240u < density);
            let twinkle = 0.65 + 0.35 * sin(frame.time * 2.0 + f32(hash & 255u) * 0.025);
            color += vec3<f32>(0.92, 0.94, 1.0) * star * twinkle * night * clear;
        }

        // A handful of bright "luceros": a rarer cell, a stronger pulse and a small cross flare.
        if want_luceros && density > 0u && hash % 8192u < density {
            let local = fract(d * 220.0) - vec3<f32>(0.5);
            let core = exp(-dot(local, local) * 90.0);
            let flare = exp(-abs(local.x) * 34.0 - abs(local.y) * 3.0)
                      + exp(-abs(local.y) * 34.0 - abs(local.x) * 3.0);
            let phase = f32(hash & 255u) * 0.05;
            let pulse = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(frame.time * 2.6 + phase), 2.0);
            let hue = mix(vec3<f32>(0.76, 0.86, 1.0), vec3<f32>(1.0, 0.92, 0.78),
                          f32(hash & 1u));
            color += hue * (core * 1.4 + flare * 0.35) * pulse * night * clear * lucero_strength;
        }
    }

    if aurora_enabled && ab_preset_at_least(PRESET_NORMAL) {
        let wave = 0.30 + 0.07 * sin(d.x * 5.0 + frame.time * 0.25) + 0.05 * sin(d.z * 7.0 - frame.time * 0.18);
        let band = exp(-pow((h - wave) / 0.16, 2.0));
        let curtain = 0.5 + 0.5 * sin(d.x * 12.0 + sin(d.z * 5.0 + frame.time * 0.2) * 2.0 + frame.time * 0.15);
        let aurora = band * pow(curtain, 2.0) * night * clear * aurora_strength;
        let hue = 0.5 + 0.5 * sin(d.x * 3.0 + frame.time * 0.1);
        color += mix(vec3<f32>(0.02, 0.36, 0.18), vec3<f32>(0.24, 0.06, 0.40), hue) * aurora;
    }

    return vec4<f32>(color, input.color.a);
}
