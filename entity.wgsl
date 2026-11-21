const LIGHT_INTENSITY: f32 = 0.45;

override aurora_lights_enabled: bool = true;

fn entity(input: EntityInput) -> Surface {
    let base = input.albedo.rgb * input.tint.rgb * input.shade;
    let gamma = vec3<f32>(1.0 / 2.2);
    let flashed = pow(mix(pow(base, gamma), pow(input.overlay.rgb, gamma), input.overlay.a), vec3<f32>(2.2));
    var light = input.lightmap;
    if aurora_lights_enabled {
        let enabled = select(0.0, 1.0, frame.mods[0].x > 0.5);
        let lamp = block_light_color(input.position);
        let reach = sqrt(clamp(lamp.a, 0.0, 1.0)) * smoothstep(0.0, 0.04, input.light.x) * enabled;
        let lamp_rgb = clamp(lamp.rgb, vec3<f32>(0.0), vec3<f32>(2.0));
        light += lamp_rgb * (reach * LIGHT_INTENSITY) + input.colored_light;
    }
    return Surface(vec4<f32>(flashed * light, input.albedo.a * input.tint.a));
}
