## Context

Hardware y estado verificados:

| Elemento | Valor observado |
|---|---|
| Equipo | ASUS Zenbook UX3402VA |
| Panel | `eDP-1`, Samsung Display `0x4171`, 2880x1800@90, escala 1,8, VRR desactivado |
| Backlight | `intel_backlight`, máximo 400, actual 316 (79 %) |
| Outputs declarados | `eDP-1`, `DP-3`, `HDMI-A-1` en `monitors.lua` |
| Shell | illogical-impulse, `qs -c ii`, familia de paneles `ii` |
| Barra | horizontal superior (`bar.bottom: false`, `bar.vertical: false`) |
| Esquinas | `appearance.fakeScreenRounding: 2` |
| Dock | activo, con `hoverToReveal` |
| Reloj de fondo | digital, fuente tamaño 90, `placementStrategy: "leastBusy"` |

Trabajo ya existente que esta change **no** rehace: `hypridle.conf` con escalonado OLED (120 s / 300 s / 330 s / 900 s), `dim_inactive = true` y `border_size = 1` en `hyprland/general.lua`.

Estructura relevante del código, verificada:

- `Bar.qml` es un `Scope` con `Variants` sobre `Quickshell.screens`, un `LazyLoader` por pantalla y dentro un `PanelWindow`. Usa `exclusionMode: ExclusionMode.Ignore` (línea 55) y calcula `exclusiveZone` a partir de `Appearance.sizes.baseBarHeight` más el hueco de Hyprland cuando `cornerStyle === 1` (líneas 56-57). La altura de la ventana es `Appearance.sizes.barHeight + Appearance.rounding.screenRounding` (línea 59). La entrada se restringe con `mask: Region { item: hoverMaskRegion }` (líneas 60-62). Anclajes en líneas 66-71.
- `VerticalBar.qml` replica la estructura sobre el eje horizontal: `baseVerticalBarWidth`, `implicitWidth`, anclajes `left`/`right` gobernados por el mismo `bar.bottom` (líneas 59-75).
- La familia `IllogicalImpulseFamily.qml` intercambia ambas con `extraCondition: Config.options.bar.vertical` (líneas 28 y 47). Solo una está cargada en cada momento.
- `Brightness.qml` es un `Singleton` con una lista de `BrightnessMonitor` derivada de `Quickshell.screens`. `increaseBrightness()` restaura antes `Hyprsunset.gamma` si no está al 100; `decreaseBrightness()` reduce la gamma cuando el brillo ya es cero. Selecciona el monitor por `Hyprland.focusedMonitor.name`. Detecta monitores DDC mediante un proceso externo.
- `AbstractBackgroundWidget.qml` coloca los widgets del fondo: `draggable` solo cuando `placementStrategy === "free"`, y calcula la región menos ocupada del wallpaper mediante un proceso externo en los demás casos.
- `ScreenCorners.qml` instancia cuatro `PanelWindow` en `WlrLayer.Overlay`, visibles según `fakeScreenRounding`, con máscara de entrada solo en la zona de apertura de las barras laterales.

## Goals / Non-Goals

**Goals:**

- Que ningún elemento permanente de la interfaz ocupe el mismo píxel de forma indefinida en `eDP-1`.
- Que el brillo máximo del panel interno esté limitado desde dentro del shell, con su OSD coherente.
- Que exista un inventario razonado de elementos estáticos, y no una lista de ajustes sin criterio.
- Que todo lo nuevo esté desactivado por defecto y sea reversible sin editar código.
- Que la configuración de monitores tenga una única fuente de verdad.

**Non-Goals:**

- No se toca `hypridle.conf`. Lo actual protege más que las alternativas evaluadas.
- No se activa VRR en `eDP-1`. En paneles OLED eDP a 90 Hz es una fuente conocida de fluctuación de luminancia; el beneficio para este caso de uso es nulo.
- No se cambia la escala del monitor. Pasar de 1,8 a otro valor reordena todo el escritorio y no aporta protección.
- No se instala `hyprpaper`. El fondo lo gestiona el propio ii mediante el módulo `Background` y el servicio `Wallpapers`; añadir un segundo gestor produciría dos capas compitiendo por `eDP-1`.
- No se instala `supergfxctl`. El UX3402VA solo tiene gráficos Intel integrados; el paquete no tiene función aquí.
- No se implementa desplazamiento del escritorio completo. Hyprland no lo ofrece y emularlo mediante desplazamiento de la geometría de las ventanas produce efectos peores que el problema que resuelve.

## Decisions

### D1 — Desplazar el contenido dentro de una ventana sobredimensionada, no la ventana

La `PanelWindow` reserva un margen adicional en su tamaño implícito y el contenido se mueve dentro de ese margen. La ventana y su `exclusiveZone` no cambian.

*Por qué:* `exclusiveZone` determina el área que Hyprland retira a las ventanas en mosaico. Desplazar la ventana o recalcular la zona provocaría recolocación de todas las ventanas en cada intervalo — visualmente intolerable y costoso. Moviendo solo el contenido, el compositor no observa cambio alguno.

*Alternativa descartada:* modificar `margins` del `PanelWindow`. En layer-shell los márgenes se traducen en reposicionamiento de la superficie, lo que reabre el mismo problema de recolocación.

*Interacción con código existente:* `Appearance.sizes.barHeight` ya suma `Appearance.rounding.screenRounding`. El margen de desplazamiento se añade sobre eso, y el cálculo de `exclusiveZone` debe seguir usando `baseBarHeight`, que no lo incluye. Es precisamente la separación entre `barHeight` y `baseBarHeight` la que hace viable este enfoque sin refactorizar.

*Pendiente de resolver en implementación:* `mask: Region { item: hoverMaskRegion }` define la región de entrada. Si el contenido se desplaza y la máscara no, los objetivos de pulsación se desalinean. La máscara debe seguir el mismo desplazamiento o anclarse al contenido desplazado.

### D2 — Amplitud pequeña, intervalo largo, transición animada

Desplazamiento de pocos píxeles, intervalo del orden de minutos, transición con animación en lugar de salto.

*Por qué:* la retención depende de la distribución acumulada de carga por píxel, no de la velocidad del movimiento. Un desplazamiento pequeño y lento reparte el desgaste igual de bien que uno grande y rápido, y no se percibe. Un salto instantáneo de varios píxeles en la barra sí se percibe y resulta molesto durante el trabajo.

*Alternativa descartada:* saltos pseudoaleatorios cada minuto con transición corta. Produce movimiento visible en la periferia del campo visual, que es donde el ojo detecta mejor el movimiento.

*A decidir con el usuario:* los valores concretos de amplitud e intervalo. Se fijan por defecto conservadores y se ajustan tras observación real.

### D3 — El tope de brillo vive en `Brightness.qml`

*Por qué:* el servicio es el único punto por el que pasan las teclas de función, el control de la interfaz y las llamadas programáticas. Un envoltorio externo de `brightnessctl` en los atajos de Hyprland dejaría el OSD mostrando valores que el hardware no tiene, y no cubriría la vía de la interfaz.

*Complicación real:* `increaseBrightness()` y `decreaseBrightness()` encadenan con `Hyprsunset.gamma`. El tope debe aplicarse al valor de brillo sin alterar esa lógica de encadenamiento, y sin que un tope alcanzado se confunda con el caso "brillo a cero" que dispara la reducción de gamma.

*Ámbito:* el recorte se aplica al monitor interno respaldado por `intel_backlight`. Los monitores DDC conservan su rango; recortarlos no aporta nada porque no son OLED.

### D4 — Ámbito por identidad de pantalla

La selección de `eDP-1` se hace por identificador estable, no por índice en `Quickshell.screens`.

*Por qué:* `Quickshell.screens` es una lista cuyo orden cambia al conectar o desconectar monitores. El propio `Bar.qml` ya filtra por `Config.options.bar.screenList` comparando `screen.name` (líneas 19-25), así que el patrón ya existe en el código y conviene seguirlo en lugar de inventar otro.

### D5 — Todo desactivado por defecto

Las opciones nuevas en `Config.options` toman valores que reproducen el comportamiento actual. Amplitud cero equivale a desactivado y no programa temporizador.

*Por qué:* estos módulos son el núcleo del shell. Un valor por defecto agresivo convierte cualquier error en un escritorio roto para cualquiera que recargue la configuración. Además permite comparar antes y después alternando una opción, que es la única forma práctica de validar que el desplazamiento no molesta.

### D6 — El conflicto de monitores se resuelve antes de tocar nada más

*Por qué:* hoy `monitors.lua` gana y `custom/general.lua` es letra muerta sin aviso. Cualquier ajuste de panel escrito en el fichero equivocado no tendría efecto y se perdería tiempo depurando un problema inexistente.

*Tensión a resolver:* `monitors.lua` está marcado como autogenerado por QuickConfig. Consolidar ahí significa que la herramienta puede sobrescribir. Consolidar en `custom/general.lua` significa que la herramienta seguirá regenerando `monitors.lua` y volverá el conflicto. No hay opción limpia; hay que elegir y documentar el modo de fallo.

### D7 — El reloj del fondo se trata aparte de la barra

Es el elemento estático de mayor superficie: fuente de tamaño 90 sobre el fondo. Se mueve solo al cambiar de wallpaper, por `placementStrategy: "leastBusy"`.

*Enfoque:* aplicar el desplazamiento como desviación sobre la posición que calcula la estrategia, sin sustituirla. Con `placementStrategy: "free"` la posición de origen es la que el usuario arrastró, y debe seguir siéndolo.

*Por qué no basta con `leastBusy`:* recalcula solo al cambiar el wallpaper. Si el wallpaper no cambia en semanas, el reloj es tan estático como la barra y bastante más grande.

## Risks / Trade-offs

- **Error de sintaxis en `Bar.qml` deja la sesión sin barra** → la recarga en caliente de Quickshell aplica el fichero roto de inmediato. Mitigación: la change `setup-ii-backup-repo` debe estar aplicada antes; validar con `qmlformat` antes de guardar; tener a mano el atajo de recarga y la ruta de restauración desde git.

- **La máscara de entrada se desalinea del contenido** → botones que no responden donde se ven. Es el fallo más probable de D1. Mitigación: verificación explícita de pulsación tras desplazamiento, incluida como escenario de especificación.

- **El desplazamiento resulta perceptible y molesta** → el usuario acaba desactivándolo y la protección se pierde. Mitigación: desactivado por defecto, amplitud e intervalo ajustables en caliente, valores finales fijados tras uso real y no en la mesa de diseño.

- **Divergencia creciente respecto a upstream** → estos cambios tocan módulos del núcleo, lo que endurece cualquier actualización futura desde `end-4/dots-hyprland`. Mitigación: concentrar la lógica nueva en el menor número de puntos de inserción posible y documentarlos en el procedimiento de comparación creado por la change anterior.

- **El tope de brillo interfiere con el encadenamiento de gamma** → un tope alcanzado podría confundirse con el caso de brillo cero y disparar cambios de gamma no deseados. Mitigación: escenarios de especificación específicos para ambos extremos del rango.

- **Consolidar monitores en el fichero autogenerado** → QuickConfig lo sobrescribe y se pierde el ajuste. Mitigación: documentar el modo de fallo junto a la declaración, cualquiera que sea el fichero elegido.

- **Protección incompleta por diseño** → nada de esto elimina el riesgo; lo reduce. Los contenidos de aplicación (barras laterales del IDE, pestañas del navegador) quedan fuera del alcance del shell. Mitigación: reconocerlo explícitamente en lugar de dar una falsa sensación de resolución.

## Migration Plan

1. **Prerrequisito** — Verificar que `setup-ii-backup-repo` está aplicada y el árbol de trabajo limpio. Sin esto, no comenzar.
2. **Fuente de verdad de monitores** — Resolver el conflicto `eDP-1` y verificar que la geometría activa no cambia.
3. **Inventario** — Recorrer la interfaz y registrar cada elemento permanente con superficie, luminosidad y contramedida prevista. Es lo que convierte las fases siguientes en decisiones y no en conjeturas.
4. **Opciones de configuración** — Añadir las opciones nuevas en `modules/common/Config.qml` con valores por defecto neutros. Verificar que el shell recarga sin cambio de comportamiento.
5. **Desplazamiento de la barra horizontal** — Implementar en `Bar.qml`, incluida la máscara de entrada. Verificar zona exclusiva constante, geometría de ventanas inalterada y pulsaciones alineadas.
6. **Desplazamiento de la barra vertical** — Trasladar a `VerticalBar.qml`. Verificar las cuatro orientaciones alternando `bar.bottom` y `bar.vertical`.
7. **Desplazamiento del reloj del fondo** — Implementar como desviación sobre `placementStrategy`, preservando el arrastre en modo `free`.
8. **Tope de brillo** — Implementar en `Brightness.qml`. Verificar ambos extremos del rango y el encadenamiento con gamma.
9. **Ajustes de tema** — Aplicar las decisiones del inventario sobre esquinas, bordes e indicadores. Las que cambien el aspecto visible se consultan antes.
10. **Verificación de ámbito** — Comprobar con monitor externo conectado que nada de lo anterior lo afecta.
11. **Ajuste de valores** — Tras uso real, fijar amplitud e intervalo definitivos.

**Rollback:** cada fase es un commit independiente sobre el repo creado por la change anterior. Revertir una fase es `git revert` de su commit más recarga del shell. Las fases 2 y 9 tocan ficheros de Hyprland y requieren además `hyprctl reload`. Si el shell queda inoperativo, la restauración es `git checkout` del árbol de ii desde la etiqueta del punto de retorno.

## Open Questions

1. ¿Qué amplitud e intervalo de desplazamiento? Se fijan por defecto conservadores y se ajustan en la fase 11 con uso real.
2. ¿Dónde se consolida la declaración de `eDP-1`: en `monitors.lua`, asumiendo que QuickConfig lo sobrescriba, o en `custom/general.lua`, asumiendo que el conflicto reaparezca al regenerar? Requiere decisión del usuario en la fase 2.
3. ¿Se conservan las cuatro esquinas falsas? Es una decisión estética con efecto visible; se plantea tras el inventario de la fase 3.
4. ¿Qué valor de tope de brillo? El panel está hoy al 79 %. Un tope por debajo del brillo habitual del usuario se percibirá como una pérdida; conviene fijarlo tras conocer el rango que usa en la práctica.
5. ¿Debe el desplazamiento pausarse mientras el panel está atenuado o apagado por `hypridle`? Mover píxeles con la pantalla apagada no aporta nada y consume ciclos de despertar; merece evaluarse durante la implementación.
