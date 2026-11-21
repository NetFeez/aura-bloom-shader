// Blocks keep vanilla's light, the Aurora Lights mod's frame lights and the palette's coloured
// block light. Water uses two world-anchored wave trains for a perturbed normal, a Fresnel-weighted
// mirror of the engine's terrain pass, a sun/moon glitter and a sheen from nearby coloured lights.
// The mirror uses an up-facing water normal for every fluid face, so it does not vanish on side
// faces or when the camera looks straight down. Outdoors it uses the engine's mirrored camera;
// indoors that pass can belong to a lake above the room, so it is replaced by a screen-space sample
// of the real scene (`opaque_color`), which also carries entities and never follows the global plane.
// Both are driven by the camera's smoothed sky light, so walking cannot make the reflection pop.
// The interior sample's vertical reach scales with distance to the fragment: a fixed screen offset
// sampled too little height near the camera, squashing a two-block object into one.
// Reading `shaded_tint` (not `tint`/`shade`/`ao`) avoids a remesh when the pack starts.

const LIGHT_INTENSITY: f32 = 0.45;
const WATER_DISABLED: u32 = 0u;
const WATER_LOW: u32 = 1u;
const WATER_NORMAL: u32 = 2u;
const WATER_ENHANCED: u32 = 3u;

override block_saturation_enabled: bool = true;
override aurora_lights_enabled: bool = true;
override world_saturation: f32 = 1.06;
override water_saturation: f32 = 1.12;
override water_ripple: f32 = 0.45;
override water_reflection_reach: f32 = 0.12;
override water_quality: u32 = 3u;

fn material(input: MaterialInput) -> Surface {
    var light = input.shaded_tint.rgb * input.lightmap;
    if aurora_lights_enabled {
        // `frame.mods[0].x` is the mod's "Light colors" switch; `colored_light` carries the lights it
        // emits each frame for held, dropped, placed and enchanted sources.
        let enabled = select(0.0, 1.0, frame.mods[0].x > 0.5);
        let lamp = block_light_color(input.position);
        let reach = sqrt(clamp(lamp.a, 0.0, 1.0)) * smoothstep(0.0, 0.04, input.light.x) * enabled;
        let lamp_rgb = clamp(lamp.rgb, vec3<f32>(0.0), vec3<f32>(2.0));
        light += lamp_rgb * (reach * LIGHT_INTENSITY) + input.colored_light;
    }
    var color = input.albedo.rgb * light;
    let base_lum = ab_luminance(color);
    if block_saturation_enabled && ab_preset_at_least(PRESET_LOW) {
        color = mix(vec3<f32>(base_lum), color, world_saturation);
    }

    // The preset caps the water detail; `water_quality` stays as the per-water fine control.
    let water_level = min(preset, water_quality);
    if input.fluid == 1u && water_level != WATER_DISABLED {
        let world = input.position + frame.camera_position;
        let top = clamp(input.normal.y, 0.0, 1.0);
        // The engine's single mirror plane is rescanned every 8 blocks/5 s and can belong to a lake
        // above an interior. Use the fragment's own surface and the camera's smoothed sky light:
        // outdoors the engine mirror is valid, indoors a screen-space sample of the real scene
        // replaces it, so surface blocks never leak into caves and nothing blinks while walking.
        let surface_y = select(ceil(world.y), world.y, top > 0.5);
        let camera_above = smoothstep(0.0, 0.5, frame.camera_position.y - surface_y);
        let sky_exposure = smoothstep(0.05, 0.5, frame.eye_light_smooth.y);
        let interior = 1.0 - sky_exposure;
        // A cool addition on top of black read as a false colour and buried the albedo, so scale it
        // by the light actually reaching this surface instead of by camera state.
        let local_light = clamp(base_lum * 4.0, 0.0, 1.0);

        // Low keeps the mirror flat; normal adds the two wave trains; enhanced sharpens the glitter
        // and strengthens the coloured-light sheen.
        let ripples = select(0.0, water_ripple, water_level >= WATER_NORMAL);
        let distortion = select(0.0, 0.05, water_level >= WATER_NORMAL);
        let sheen = select(0.04, select(0.14, 0.30, water_level == WATER_ENHANCED),
                           water_level >= WATER_NORMAL);
        let glitter_power = select(70.0, select(110.0, 160.0, water_level == WATER_ENHANCED),
                                   water_level >= WATER_NORMAL);

        // Two wave trains give an analytic slope, so the surface can reflect and glitter instead
        // of just being tinted. The phases are world-anchored and move with the frame's time.
        let k1 = vec2<f32>(0.9, 0.65);
        let k2 = vec2<f32>(1.7, -1.1);
        let p1 = dot(world.xz, k1) + frame.time * 1.6;
        let p2 = dot(world.xz, k2) - frame.time * 1.1;
        let wave = 0.5 + 0.5 * sin(p1) * sin(p2);
        let slope = ripples * (0.045 * cos(p1) * k1 + 0.028 * cos(p2) * k2);
        // The mirror and its Fresnel use the water surface, not the mesher's fluid face. Side and
        // bottom faces are only the boundary of that surface; using their normal killed the
        // reflection at shorelines and low viewpoints. An up normal with the wave slope keeps the
        // same reflection across the whole water body.
        let surface_normal = normalize(vec3<f32>(slope.x, 1.0, slope.y));
        let normal = normalize(vec3<f32>(input.normal.x + slope.x * top,
                                        max(input.normal.y, 0.1),
                                        input.normal.z + slope.y * top));
        let view = normalize(-input.position);
        let grazing = 1.0 - clamp(dot(view, surface_normal), 0.0, 1.0);
        let fresnel = grazing * grazing * grazing;

        var water = mix(vec3<f32>(base_lum), color, water_saturation)
                  * vec3<f32>(0.78, 0.94, 1.12);
        water += vec3<f32>(0.015, 0.045, 0.065) * wave * top * ripples * local_light;

        let mirror_strength = clamp(0.28 + 0.55 * fresnel, 0.0, 0.83) * camera_above;
        if frame.has_reflection == 1u && sky_exposure > 0.0 {
            let uv = clamp(input.screen + slope * distortion * top,
                           vec2<f32>(0.001), vec2<f32>(0.999));
            let mirrored = textureSampleLevel(reflection, reflection_sampler, uv, 0.0).rgb;
            water = mix(water, mirrored * vec3<f32>(0.94, 0.98, 1.04),
                        mirror_strength * sky_exposure);
        }
        if interior > 0.0 {
            // `opaque_color` is the decoded world picture before translucent terrain: cave walls,
            // plants and entities. Sampling above this fragment approximates their image without
            // the engine's global plane, so a beach above the room cannot leak in. The offset is in
            // screen space, so the world height it covers grows with distance: scale it by 1/d to
            // keep a two-block object two blocks tall when the camera moves closer or further away.
            let distance = max(length(input.position), 0.5);
            let lift = clamp(water_reflection_reach * clamp(5.0 / distance, 0.3, 3.0)
                             * (0.55 + 0.45 * clamp(grazing, 0.0, 1.0)),
                             0.01, 0.35);
            let local_uv = clamp(input.screen + slope * distortion * 2.0
                                 + vec2<f32>(0.0, -lift),
                                 vec2<f32>(0.001), vec2<f32>(0.999));
            let local = textureLoad(opaque_color, vec2<i32>(local_uv * frame.resolution), 0).rgb;
            water = mix(water, local * vec3<f32>(0.94, 0.98, 1.04),
                        clamp(0.26 + 0.34 * fresnel, 0.0, 0.6) * interior * camera_above);
        }

        if aurora_lights_enabled {
            // `colored_light` is accumulated linear light, with no direction to mirror exactly.
            // Fresnel and wave crests shape it into a sheen so lights near the water still read.
            let w2 = wave * wave;
            let crest = select(0.0, w2 * w2 * w2, water_level >= WATER_NORMAL);
            water += input.colored_light * sheen * (0.25 + 0.75 * fresnel + 0.5 * crest) * top;
        }

        // Specular sun by day, moonlight by night, broken up by the wave normal.
        let halfway = normalize(frame.light_direction + view);
        let spec = pow(max(dot(normal, halfway), 0.0), glitter_power);
        let sunlight = mix(vec3<f32>(0.55, 0.68, 0.92) * 0.25,
                           vec3<f32>(1.0, 0.93, 0.78) * 1.6, ab_day());
        water += sunlight * spec * top * (1.0 - clamp(frame.rain, 0.0, 1.0) * 0.7) * sky_exposure;
        color = mix(color, water, 0.55 + 0.35 * top);
    }

    return Surface(vec4<f32>(color, input.albedo.a));
}
