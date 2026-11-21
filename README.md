# Aurora Bloom

A Horizon shader pack (API 0.2) for a prettier world without changing how it plays. It is the only
recommended companion shader for the `netfeez_aurora_lights` mod

Repo: https://github.com/netfeez/aura-bloom-shader
Mod repo: https://github.com/netfeez/aura-lights-mod

- **Sky** (`sky.wgsl`): a deeper blue day sky with a warm halo at sunrise and sunset, a dark
  violet night with twinkling stars and a few brighter "luceros" that pulse and flare, and slow
  aurora curtains. Uses vanilla's sky colour as its base, so weather and the two Overworld
  sun/moon phases still read as they should.
- **Water and blocks** (`material.wgsl`): a small saturation lift on blocks; water can mirror the
  world, ripple with two world-anchored wave trains, glitter from the sun/moon and pick up a
  colored sheen from nearby lights. Reads `shaded_tint`, so it does not force a terrain remesh.
- **Entities** (`entity.wgsl`): the same coloured-light formula as the legacy Aurora Lights shader
  repo, so held, dropped, framed and enchanted gear light players and mobs.
- **Grade** (`tonemap.wgsl`): gentle saturation, contrast, a soft shoulder and a light vignette.
  Reuses Horizon's HDR tone curve and reads no `previous`, so FXAA/TAA stay on.

## Presets and options

`Presets` is the first option on the shader pack's options page:

| Preset | What it enables |
|---|---|
| `only lights` | Aurora Lights glow only: no sky effects, water effects or grade. The mirror render pass is skipped. |
| `low` | Sky tint, sun/moon glow, block saturation, flat water mirror and the basic grade. |
| `normal` | Adds stars, aurora, rippled water and the vignette. |
| `enhanced` | Default. Adds luceros and the sharper water glitter and stronger colored sheen. |

Every effect also has its own switch, all On by default. The preset is a ceiling for cosmetic
groups; a switch can turn an allowed effect off, but a group above the preset level stays off. The
sliders set how much of an enabled effect is applied. Aurora Lights glow is deliberately outside
the preset, so `only lights` keeps exactly that.

Option names and descriptions are shown in English: the shader-pack format has no language-file
support. Option ids and values (`preset`, `water_quality`, etc.) stay in English for compatibility.

## Water quality

`Water quality` remains as fine control and is capped by `Presets`: the effective water level is
the lower of the two. With the default `enhanced` preset, all four water values are available.

| Value | Behaviour |
|---|---|
| `disabled` | No water effects. |
| `low` | Flat Fresnel mirror and cool tint, without animated waves. |
| `normal` | Rippled mirror, wave distortion, sun/moon glitter and colored-light sheen. |
| `enhanced` | Default. Same as `normal`, with a sharper glitter and a stronger colored-light sheen. |

The engine's mirror pass contains solid terrain and the vanilla sky gradient, not this pack's sky,
entities or item models. Held, dropped, framed, placed and enchanted lights therefore reach water
through `input.colored_light`, which the pack shapes into a Fresnel-and-wave-weighted sheen. The API
provides accumulated linear light rather than individual light directions, so this is a sheen, not
an exact mirror image of each source.

The mirror uses an up-facing water normal for every fluid face, with a cubic Fresnel and a visible
minimum, so it does not disappear at shorelines, on side faces or when looking straight down. The
outdoor/indoor crossfade and the sun/moon glitter use `frame.eye_light_smooth` (2 s half-life), not
raw sky light, so walking through a cave mouth does not make them pop.

The engine still uses one global `frame.water_plane` for the whole mirror, rescanned every 8 blocks
or 5 s. In an isolated room that plane can belong to a lake or beach above, so the engine mirror
would show those blocks instead of the room. Aurora Bloom uses that mirror only under the open sky.
Indoors it samples `opaque_color` above the water fragment instead: that texture is the real scene
before translucent terrain, including cave walls, plants and entities, and does not depend on the
global plane. The screen-space offset is scaled by 1/distance so a two-block object stays two blocks
tall when you move closer or further away; `Interior reflection reach` adjusts it if needed. The
local sample is an approximation, not a true mirror, but it shows the correct room. The mod's colored
sheen stays, so luminous items still light water.

The engine's mirror contains terrain, not the sun disc, so no bright-pixel filtering is needed. The
cool wave tint scales with the light actually reaching the surface, so full darkness does not invent
a blue colour or bury the albedo.

Build and check with:

```sh
stage=$(mktemp -d)
cp horizon-shaders.toml *.wgsl icon.png README.md "$stage"/
horizon-shader check "$stage"
horizon-shader pack "$stage" --out AuroraBloom-0.1.0.hshader
horizon-shader check AuroraBloom-0.1.0.hshader
```

Install by copying the folder or the `.hshader` into the instance's `shaderpacks/` next to
`options.txt`, then select it once in Shader Packs.

## Aurora Lights compatibility

This pack works with the `netfeez_aurora_lights` mod. Its material and entity stages add
`input.colored_light` (the mod's held, dropped, placed, framed and enchanted-gear lights) and read
`block_light_color` with the same palette and falloff as the legacy shader repo;
`frame.mods[0].x` gates that palette on the mod's "Light colors" setting.

Only one shader pack can be active at a time, so select Aurora Bloom alone. Do not also enable
Horizon Extras > Dynamic Lights: the mod already emits the lights and running both would duplicate
them. Turn the mod's "Light colors" setting On for colored rather than white light.

The pack cannot alter the vanilla enchantment glint itself: the glint is applied after the
shader stages and the API does not expose an enchantment mask. The mod adds a faint violet halo
around enchanted gear instead; that halo is read here as `colored_light`.
