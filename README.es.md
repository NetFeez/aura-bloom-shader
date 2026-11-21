# Aurora Bloom

Paquete de shaders para Horizon (API 0.2) que mejora el aspecto del mundo sin cambiar la jugabilidad.
Es el paquete recomendado para el mod Aurora Lights.

Repo: https://github.com/netfeez/aura-bloom-shader
Repo del mod: https://github.com/netfeez/aura-lights-mod

- **Cielo** (`sky.wgsl`): azul diurno más profundo con halo cálido al amanecer y al atardecer, noche
  violeta con estrellas parpadeantes y algunos «luceros» más brillantes que pulsan y destellan, y
  cortinas de aurora lentas. Usa el color de cielo vanilla como base, así que el clima y las dos
  fases sol/luna del Overworld siguen leyéndose como deben.
- **Agua y bloques** (`material.wgsl`): un pequeño aumento de saturación en bloques; el agua puede
  reflejar el mundo, ondularse con dos trenes de olas anclados al mundo, destellar con sol/luna y
  recoger un brillo de colores de las luces cercanas. Lee `shaded_tint`, así que no fuerza una
  recarga de la malla del terreno.
- **Entidades** (`entity.wgsl`): la misma fórmula de luz coloreada del repo de shader legacy de
  Aurora Lights, para que objetos en mano, caídos, enmarcados y encantados iluminen jugadores y mobs.
- **Reajuste final** (`tonemap.wgsl`): saturación, contraste, hombro suave y viñeta ligera. Reutiliza
  la curva HDR de Horizon y no lee `previous`, así que FXAA/TAA siguen activos.

## Predefinidos y opciones

`Presets` es la primera opción en la página de opciones del paquete:

| Predefinido | Qué activa |
|---|---|
| `only lights` | Solo el brillo de Aurora Lights: sin efectos de cielo, agua ni reajuste. Se omite el pase de reflejo. |
| `low` | Tinte de cielo, halo de sol/luna, saturación de bloques, reflejo de agua plano y reajuste básico. |
| `normal` | Añade estrellas, aurora, agua ondulada y la viñeta. |
| `enhanced` | Predeterminado. Añade luceros, destello de agua más nítido y brillo de colores más fuerte. |

Todos los efectos tienen además su propio interruptor, activado por defecto. El predefinido actúa como
techo de los grupos cosméticos: un interruptor puede desactivar un efecto permitido, pero un grupo por
encima del predefinido sigue desactivado. Los deslizadores ajustan cuánto se aplica un efecto activado.
El brillo de Aurora Lights queda deliberadamente fuera de los predefinidos, así que `only lights`
conserva exactamente eso.

Los nombres y descripciones de las opciones se muestran en inglés: el formato de paquetes de shaders
no admite archivos de idioma. Los ids y valores (`preset`, `water_quality`, etc.) se mantienen en
inglés por compatibilidad.

## Calidad del agua

`Water quality` sigue siendo el control fino y está limitado por `Presets`: el nivel efectivo es el
menor de ambos. Con el predefinido `enhanced`, los cuatro valores están disponibles.

| Valor | Comportamiento |
|---|---|
| `disabled` | Sin efectos de agua. |
| `low` | Reflejo Fresnel plano y tinte frío, sin olas animadas. |
| `normal` | Reflejo ondulado, distorsión de olas, destello de sol/luna y brillo de luz coloreada. |
| `enhanced` | Predeterminado. Igual que `normal`, con destello más nítido y brillo de colores más fuerte. |

El pase de reflejo del motor contiene terreno sólido y el degradado de cielo vanilla, no el cielo de
este paquete, entidades ni modelos de objetos. Por eso las luces en mano, caídas, enmarcadas,
colocadas y encantadas llegan al agua mediante `input.colored_light`, que el paquete transforma en un
brillo ponderado por Fresnel y por las olas. La API entrega luz lineal acumulada, no direcciones
individuales, así que es un brillo, no un reflejo exacto de cada fuente.

El reflejo usa una normal de agua hacia arriba en cada cara del fluido, con un Fresnel cúbico y un
mínimo visible, para que no desaparezca en orillas, caras laterales ni mirando desde arriba. El
fundido entre exterior e interior y el destello de sol/luna usan `frame.eye_light_smooth` (vida media
de 2 s), no la luz de cielo en crudo, para que caminar por la boca de una cueva no los haga parpadear.

El motor sigue usando un único `frame.water_plane` global para todo el reflejo, que se reescanea cada
8 bloques o 5 s. En una sala aislada ese plano puede pertenecer a un lago o una playa superiores, y el
reflejo del motor mostraría esos bloques en vez de la sala. Aurora Bloom usa ese reflejo solo a cielo
abierto. En interiores muestrea `opaque_color` por encima del fragmento de agua: esa textura es la
escena real antes del terreno translúcido, incluye paredes, plantas y entidades, y no depende del
plano global. El desplazamiento en pantalla se escala con `1 / distancia` para que un objeto de dos
bloques siga midiendo dos bloques al acercarte o alejarte; `Interior reflection reach` lo ajusta si
hace falta. La muestra local es una aproximación, no un espejo geométrico, pero muestra la sala
correcta. El brillo de colores del mod sigue ahí, así que los objetos luminosos siguen iluminando el
agua.

El reflejo del motor no contiene el disco solar, así que no hace falta filtrar píxeles brillantes. El
tinte frío de las olas se escala con la luz que llega realmente a la superficie, para que la oscuridad
total no invente un azul falso ni entierre el albedo.

## Compilación e instalación

```sh
stage=$(mktemp -d)
cp horizon-shaders.toml *.wgsl icon.png README.md "$stage"/
horizon-shader check "$stage"
horizon-shader pack "$stage" --out AuroraBloom-0.1.0.hshader
horizon-shader check AuroraBloom-0.1.0.hshader
```

Copia la carpeta o el `.hshader` en la carpeta `shaderpacks` junto a `options.txt` y selecciona el
paquete una vez en Shader Packs.

## Compatibilidad con Aurora Lights

Este paquete funciona con el mod Aurora Lights. Sus etapas material y de entidades añaden
`input.colored_light` (las luces en mano, caídas, colocadas, enmarcadas y de objetos encantados que
emite el mod) y leen `block_light_color` con la misma paleta y caída que el repo de shader legacy;
`frame.mods[0].x` condiciona esa paleta al ajuste «Light colors» del mod.

Solo puede haber un paquete de shaders activo a la vez, así que selecciona Aurora Bloom únicamente.
No actives también **Horizon Extras > Dynamic Lights**: el mod ya emite las luces y ejecutar ambos las
duplicaría. Activa el ajuste «Light colors» del mod para obtener luz coloreada en vez de blanca.

El paquete no puede alterar el glint vanilla de encantamientos: se aplica después de las etapas del
shader y la API no expone una máscara de encantamiento. El mod añade un halo violeta tenue alrededor
de los objetos encantados; aquí ese halo se lee como `colored_light`.
