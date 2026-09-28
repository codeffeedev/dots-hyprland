## ADDED Requirements

### Requirement: `eDP-1` se declara en un único fichero

La configuración de Hyprland SHALL declarar el monitor `eDP-1` exactamente una vez. Los ficheros `~/.config/hypr/monitors.lua` y `~/.config/hypr/custom/general.lua` MUST NOT contener ambos una llamada `hl.monitor` para el mismo output.

#### Scenario: Una sola declaración
- **WHEN** se buscan llamadas `hl.monitor` que mencionen `eDP-1` en todo `~/.config/hypr/`
- **THEN** se encuentra exactamente una

#### Scenario: El estado en ejecución coincide con lo declarado
- **WHEN** se compara la salida de `hyprctl monitors` para `eDP-1` con la declaración superviviente
- **THEN** la posición, el modo y la escala coinciden

### Requirement: La fuente de verdad está documentada

El fichero que conserva la declaración SHALL indicar en un comentario por qué es el autoritativo y qué ocurre si otra herramienta regenera declaraciones en conflicto. `monitors.lua` está marcado como autogenerado por QuickConfig, lo que MUST tenerse en cuenta al decidir dónde se escribe.

#### Scenario: El comentario existe
- **WHEN** se lee el fichero que conserva la declaración de `eDP-1`
- **THEN** contiene un comentario que lo identifica como fuente de verdad y menciona el riesgo de regeneración automática

#### Scenario: El fichero desplazado no queda silenciosamente vacío
- **WHEN** se lee el fichero del que se retiró la declaración
- **THEN** contiene un comentario que indica dónde se ha trasladado, o bien ha sido eliminado de forma deliberada y registrada

### Requirement: La resolución del conflicto no altera el escritorio en uso

El cambio de fuente de verdad SHALL preservar la geometría actualmente activa: `2880x1800@90`, escala `1.8`. La posición MUST elegirse de forma explícita, dejando constancia de cuál de las dos declaraciones en conflicto prevalece.

#### Scenario: La geometría se preserva
- **WHEN** se recarga la configuración de Hyprland tras el cambio
- **THEN** `hyprctl monitors` sigue informando `2880x1800@90` y escala `1.8` para `eDP-1`

#### Scenario: Las ventanas abiertas no se recolocan
- **WHEN** se recarga la configuración con ventanas abiertas
- **THEN** ninguna ventana cambia de espacio de trabajo ni queda fuera del área visible
