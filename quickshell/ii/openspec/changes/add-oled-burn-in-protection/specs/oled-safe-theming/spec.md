## ADDED Requirements

### Requirement: Los elementos permanentes de la interfaz quedan inventariados

La change SHALL producir un inventario de todo elemento que permanece visible y sin cambiar de posición durante una sesión de trabajo normal. El inventario MUST registrar, para cada elemento, su superficie aproximada, su luminosidad relativa y la contramedida aplicada o la razón de no aplicar ninguna.

#### Scenario: El inventario cubre los elementos conocidos
- **WHEN** se revisa el inventario resultante
- **THEN** incluye al menos la barra, las cuatro esquinas de `ScreenCorners`, el dock, el reloj del fondo y los bordes de ventana de Hyprland

#### Scenario: Cada entrada tiene resolución
- **WHEN** se revisa cualquier entrada del inventario
- **THEN** indica una contramedida aplicada o una justificación explícita de por qué no se aplica ninguna

### Requirement: Las esquinas falsas de pantalla se revisan

`appearance.fakeScreenRounding` vale `2`, lo que mantiene cuatro `PanelWindow` dibujadas en `WlrLayer.Overlay` salvo en pantalla completa. La change SHALL evaluar su contribución al riesgo y dejar constancia de la decisión tomada.

#### Scenario: La decisión queda registrada
- **WHEN** se consulta el resultado de la evaluación
- **THEN** indica si las esquinas se conservan, se atenúan o se desactivan, con el motivo

#### Scenario: El cambio estético es explícito
- **WHEN** la decisión implica modificar `fakeScreenRounding`
- **THEN** el cambio se presenta al usuario como decisión estética antes de aplicarse, por afectar visiblemente a las cuatro esquinas de la pantalla

### Requirement: Los bordes de ventana no son candidatos a retención

Los colores de borde de ventana de Hyprland SHALL evitar tonos saturados y de alta luminosidad en el borde activo, por ser una línea fija en la misma posición durante toda la sesión. `border_size = 1` y `dim_inactive = true` ya presentes en `~/.config/hypr/hyprland/general.lua` MUST conservarse.

#### Scenario: El borde activo no es un color saturado brillante
- **WHEN** se inspecciona el color de borde activo tras la change
- **THEN** su luminosidad y saturación están por debajo del umbral acordado en el inventario

#### Scenario: Los ajustes previos se conservan
- **WHEN** se recarga la configuración de Hyprland tras la change
- **THEN** `border_size` sigue valiendo 1 y `dim_inactive` sigue activo

### Requirement: El escalonado de inactividad existente no se degrada

`~/.config/hypr/hypridle.conf` implementa atenuación al 10 % a los 120 s, bloqueo a los 300 s, apagado del panel a los 330 s y suspensión a los 900 s. La change SHALL NOT sustituir ese escalonado por uno menos protector.

#### Scenario: Los umbrales no se relajan
- **WHEN** se compara `hypridle.conf` antes y después de la change
- **THEN** ningún umbral se ha incrementado y el apagado del panel sigue produciéndose a los 330 s

#### Scenario: El apagado del panel sigue siendo efectivo
- **WHEN** se deja el equipo inactivo más allá del umbral de apagado
- **THEN** el panel se apaga realmente y se restaura al reanudar la actividad, junto con el brillo previo

### Requirement: Los indicadores permanentes de la barra se moderan

Los elementos de la barra que muestran contenido constante —reloj, meteorología, indicadores de recursos— SHALL revisarse para evitar texto de alta luminosidad fijo en la misma posición. La legibilidad MUST conservarse.

#### Scenario: Ningún indicador usa el nivel de luminosidad máximo
- **WHEN** se inspeccionan los colores de primer plano de los indicadores permanentes
- **THEN** ninguno emplea blanco puro ni el nivel máximo de luminosidad del tema

#### Scenario: El contenido sigue siendo legible
- **WHEN** se observa la barra en condiciones de iluminación normales tras el ajuste
- **THEN** el reloj y los indicadores se leen sin esfuerzo

#### Scenario: El tema derivado del wallpaper sigue funcionando
- **WHEN** se cambia el wallpaper y se regeneran los colores Material3
- **THEN** los ajustes de moderación siguen aplicándose sobre la paleta nueva, sin quedar sobrescritos
