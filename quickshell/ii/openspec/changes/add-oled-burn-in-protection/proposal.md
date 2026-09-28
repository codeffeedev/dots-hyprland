## Why

El equipo es un ASUS Zenbook UX3402VA con panel OLED Samsung (`eDP-1`, 2880x1800@90). El escritorio mantiene permanentemente en pantalla varios elementos que no se mueven nunca: la barra de ii, las cuatro esquinas falsas de `ScreenCorners` (`appearance.fakeScreenRounding: 2`), el dock y el reloj digital del fondo a tamaño de fuente 90. Esos elementos son exactamente el patrón que produce retención de imagen en OLED: estáticos, iluminados y presentes durante sesiones largas de trabajo.

Parte del trabajo de protección ya está hecha y no debe repetirse: `hypridle.conf` tiene un escalonado con comentarios OLED explícitos (atenuación al 10 % a los 2 min, bloqueo a los 5, DPMS a los 5,5 y suspensión a los 15) y `hyprland/general.lua:103` ya activa `dim_inactive`. Lo que falta es el desplazamiento de píxeles de los elementos permanentes, un tope real de brillo integrado en el shell, y la revisión de los elementos estáticos que nadie ha auditado todavía.

Existe además un defecto de configuración que bloquea cualquier ajuste fiable del monitor: `~/.config/hypr/monitors.lua` declara `eDP-1` en la posición `240x560` y `~/.config/hypr/custom/general.lua` lo declara en `0x0`. Hoy gana el primero, lo que convierte al segundo en letra muerta sin que nada lo advierta. Mientras esa ambigüedad exista, no hay un lugar fiable donde escribir configuración de panel.

## What Changes

- Se añade desplazamiento periódico de píxeles a la barra, en sus dos variantes (`modules/ii/bar/Bar.qml` y `modules/ii/verticalBar/VerticalBar.qml`), sin alterar la zona exclusiva ni provocar recolocación de ventanas.
- Se aplica el mismo tratamiento al reloj del fondo, cuyo desplazamiento hoy solo ocurre al cambiar de wallpaper por la estrategia `leastBusy`.
- Se introduce un tope de brillo dentro del servicio `Brightness` de ii, en lugar de un script externo que desincronizaría el OSD de brillo.
- Se restringe toda la protección al panel interno `eDP-1`; los monitores externos `DP-3` y `HDMI-A-1` quedan sin modificar.
- Se auditan y ajustan los elementos estáticos restantes: las esquinas de `ScreenCorners`, los colores de borde de ventana de Hyprland y el peso visual de los indicadores permanentes de la barra.
- Se resuelve el conflicto de declaración de `eDP-1` entre `monitors.lua` y `custom/general.lua`, fijando una única fuente de verdad.
- Se añaden opciones de configuración nuevas bajo `Config.options`, con valores por defecto que dejan el comportamiento actual intacto hasta que se activen explícitamente.
- **BREAKING**: si se decide reducir `fakeScreenRounding`, el aspecto de las cuatro esquinas de la pantalla cambia de forma visible. Es un cambio estético deliberado, no un efecto secundario.

## Capabilities

### New Capabilities
- `static-element-pixel-shift`: desplazamiento periódico de los elementos permanentes de la interfaz, sus límites y su interacción con la zona exclusiva de layer-shell.
- `oled-brightness-cap`: tope máximo de brillo del panel interno, integrado en el servicio de brillo del shell y coherente con su OSD.
- `oled-safe-theming`: reglas sobre qué elementos permanentes pueden mostrarse y con qué intensidad — esquinas falsas, bordes de ventana, indicadores de la barra.
- `internal-panel-scoping`: garantía de que la protección OLED afecta solo a `eDP-1` y nunca a los monitores externos.
- `hyprland-config-source-of-truth`: fuente única de verdad para la declaración de monitores, prerrequisito de todo lo anterior.

### Modified Capabilities
<!-- Ninguna: openspec/specs/ está vacío. Las capacidades de setup-ii-backup-repo aún no se han archivado como especificaciones vigentes. -->

## Impact

Módulos del shell afectados:

- `modules/ii/bar/Bar.qml` — núcleo del shell. Usa `exclusionMode: ExclusionMode.Ignore` (línea 55), un `exclusiveZone` calculado (líneas 56-57) y `mask: Region` para la detección de hover (líneas 60-62). El desplazamiento debe convivir con los tres.
- `modules/ii/verticalBar/VerticalBar.qml` — estructura equivalente para los bordes izquierdo y derecho.
- `modules/ii/background/widgets/AbstractBackgroundWidget.qml` — colocación del reloj, hoy por `placementStrategy`.
- `modules/ii/screenCorners/ScreenCorners.qml` — cuatro `PanelWindow` en `WlrLayer.Overlay`.
- `services/Brightness.qml` — singleton con un `BrightnessMonitor` por pantalla; encadena con `Hyprsunset.gamma` al llegar a cero.
- `modules/common/Config.qml` — nuevas opciones de configuración y sus valores por defecto.
- `modules/common/Appearance.qml` — `sizes.barHeight` y `sizes.verticalBarWidth` dependen de `bar.cornerStyle`; el desplazamiento no debe desajustar ese cálculo.

Ficheros de Hyprland afectados:

- `~/.config/hypr/custom/general.lua` y `~/.config/hypr/monitors.lua` — resolución del conflicto de `eDP-1`.
- `~/.config/hypr/hyprland/general.lua` — colores de borde; ya tiene `border_size = 1` y `dim_inactive = true`.

Sin cambios: `hypridle.conf` se conserva tal cual. Su escalonado actual protege más que cualquier alternativa considerada.

Dependencia previa: la change `setup-ii-backup-repo` debe estar aplicada. Esta change modifica módulos del núcleo del shell, y sin el punto de retorno versionado un error deja el escritorio inutilizable sin vía de recuperación.

Riesgo operativo: un error de sintaxis QML en `Bar.qml` deja la sesión sin barra. El procedimiento debe contemplar edición y verificación con la sesión en marcha, aprovechando la recarga en caliente de Quickshell.
