## ADDED Requirements

### Requirement: El brillo del panel interno tiene un tope configurable

El servicio `Brightness` SHALL impedir que el brillo de `eDP-1` supere un máximo configurable. El tope MUST aplicarse a cualquier vía de subida, incluidas las teclas de función, el control deslizante de la interfaz y cualquier llamada programática.

#### Scenario: La subida repetida se detiene en el tope
- **WHEN** se solicita subir el brillo repetidamente hasta agotar el rango
- **THEN** el brillo se estabiliza en el valor del tope y no alcanza el máximo del hardware

#### Scenario: El tope se aplica al arrancar
- **WHEN** el shell arranca con un brillo del panel por encima del tope
- **THEN** el brillo se reduce hasta el tope

#### Scenario: El tope es ajustable en caliente
- **WHEN** se modifica el valor del tope en la configuración
- **THEN** el nuevo límite se aplica de inmediato, reduciendo el brillo actual si lo excede

### Requirement: El indicador de brillo refleja el tope

El OSD de brillo del shell SHALL mostrar un valor coherente con el brillo realmente aplicado. MUST NOT indicar un nivel que el tope ha impedido alcanzar.

#### Scenario: El OSD no muestra un valor inalcanzable
- **WHEN** se pulsa la tecla de subir brillo con el brillo ya en el tope
- **THEN** el OSD muestra el valor del tope, no un valor superior

#### Scenario: El indicador permanece sincronizado
- **WHEN** el tope reduce el brillo al arrancar
- **THEN** cualquier indicador de brillo de la interfaz muestra el valor reducido, no el previo

### Requirement: El encadenamiento con gamma se preserva

El servicio `Brightness` encadena con `Hyprsunset.gamma`: al subir restaura antes la gamma si no está al 100, y al bajar por debajo de cero reduce la gamma. Ese comportamiento SHALL conservarse íntegro tras introducir el tope.

#### Scenario: La gamma se restaura antes que el brillo
- **WHEN** la gamma está por debajo de 100 y se solicita subir el brillo
- **THEN** primero se incrementa la gamma, como hasta ahora, sin que el tope interfiera

#### Scenario: La reducción por debajo de cero sigue bajando la gamma
- **WHEN** el brillo está a cero y se solicita bajar más
- **THEN** la gamma disminuye, como hasta ahora

### Requirement: El tope no se implementa fuera del shell

El límite SHALL residir en el servicio `Brightness` de ii. MUST NOT implementarse mediante un envoltorio externo de `brightnessctl` invocado desde los atajos de Hyprland, porque esa vía deja el OSD del shell desincronizado con el brillo real.

#### Scenario: No se introducen scripts envoltorio
- **WHEN** se revisan los cambios de la change
- **THEN** no se ha añadido ningún script que invoque `brightnessctl` por fuera del servicio `Brightness`

#### Scenario: Los atajos existentes siguen pasando por el shell
- **WHEN** se pulsan las teclas de brillo
- **THEN** la acción se resuelve a través del servicio del shell y el OSD aparece

### Requirement: El tope no afecta a monitores externos

El límite SHALL aplicarse exclusivamente al panel interno respaldado por `intel_backlight`. Los monitores gestionados por `ddcutil` MUST conservar su rango completo.

#### Scenario: Un monitor DDC alcanza su máximo
- **WHEN** se sube al máximo el brillo de un monitor externo gestionado por DDC
- **THEN** alcanza su valor máximo sin recorte
