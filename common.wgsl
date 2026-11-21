// Shared helpers for Aurora Bloom: a cell hash for stars and water glints, the day/night factor,
// and Horizon's HDR tone curve (adapted from the local `horizon_hdr` pack) so a `[tonemap]` stage
// grades the picture without throwing away the display mapping.

// The global preset is a ceiling for cosmetic groups; individual switches stay as fine control.
// Aurora Lights glow is deliberately not gated, so `only lights` keeps exactly that.
const PRESET_LOW: u32 = 1u;
const PRESET_NORMAL: u32 = 2u;
const PRESET_ENHANCED: u32 = 3u;

override preset: u32 = 3u;

fn ab_preset_at_least(level: u32) -> bool {
    return preset >= level;
}

fn ab_hash(cell: vec3<i32>) -> u32 {
    let h = bitcast<vec3<u32>>(cell) * vec3<u32>(73856093u, 19349663u, 83492791u);
    var x = h.x ^ h.y ^ h.z;
    x = (x ^ (x >> 16u)) * 0x7feb352du;
    x = (x ^ (x >> 15u)) * 0x846ca68bu;
    return x ^ (x >> 16u);
}

fn ab_day() -> f32 {
    return select(0.0, smoothstep(-0.12, 0.12, frame.sun_direction.y), frame.dimension == 0);
}

fn ab_night() -> f32 {
    return (1.0 - ab_day()) * select(0.0, 1.0, frame.dimension == 0);
}

fn ab_luminance(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

// SMPTE ST 2084, and its inverse: nits <-> PQ signal.
fn ab_pq(nits: vec3<f32>) -> vec3<f32> {
    let y = pow(clamp(nits / 10000.0, vec3<f32>(0.0), vec3<f32>(1.0)), vec3<f32>(0.1593017578125));
    return pow((vec3<f32>(0.8359375) + 18.8515625 * y) / (vec3<f32>(1.0) + 18.6875 * y), vec3<f32>(78.84375));
}

fn ab_pq_nits(e: vec3<f32>) -> vec3<f32> {
    let p = pow(clamp(e, vec3<f32>(0.0), vec3<f32>(1.0)), vec3<f32>(1.0 / 78.84375));
    let y = max(p - vec3<f32>(0.8359375), vec3<f32>(0.0)) / (vec3<f32>(18.8515625) - 18.6875 * p);
    return 10000.0 * pow(y, vec3<f32>(1.0 / 0.1593017578125));
}

// The knee of BT.2390's EETF where a pack's own light has no known peak: 60% of the headroom,
// at least paper white.
fn ab_tone_knee(headroom: f32) -> f32 {
    return max(0.6 * headroom, 1.0);
}

// Scale for linear light whose brightest channel is `top`, so it fits `headroom` times paper
// white. The source has no known peak (this pack lifts no light source), exactly the case
// Horizon's own curve handles for a shader pack's light.
fn ab_tone_scale(top: f32, headroom: f32, paper: f32) -> f32 {
    let peak = ab_pq(vec3<f32>(headroom * paper)).x;
    if top <= ab_tone_knee(headroom) {
        return 1.0;
    }
    let source = min(3.0 * peak - 2.0 * ab_pq(vec3<f32>(ab_tone_knee(headroom) * paper)).x, 1.0);
    let e = ab_pq(vec3<f32>(top * paper)).x / source;
    let max_lum = peak / source;
    let ks = max(1.5 * max_lum - 0.5, 0.0);
    if e >= 1.0 {
        return headroom / top;
    }
    if e <= ks {
        return 1.0;
    }
    let t = (e - ks) / (1.0 - ks);
    let t2 = t * t;
    let t3 = t2 * t;
    let p = (2.0 * t3 - 3.0 * t2 + 1.0) * ks + (t3 - 2.0 * t2 + t) * (1.0 - ks) + (3.0 * t2 - 2.0 * t3) * max_lum;
    return ab_pq_nits(vec3<f32>(p * source)).x / paper / top;
}
