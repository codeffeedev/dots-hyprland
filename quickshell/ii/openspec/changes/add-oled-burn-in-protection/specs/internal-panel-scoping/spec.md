## ADDED Requirements

### Requirement: La protección OLED se aplica solo al panel interno

Todo comportamiento introducido por esta change —desplazamiento de píxeles, tope de brillo y atenuación de elementos permanentes— SHALL aplicarse únicamente a la pantalla `eDP-1`. Los outputs externos `DP-3` y `HDMI-A-1`, declarados en `~/.config/hypr/monitors.lua`, MUST quedar con su comportamiento actual.

#### Scenario: La barra externa no se desplaza
- **WHEN** hay un monitor externo conectado y el desplazamiento de píxeles está activo
- **THEN** la instancia de la barra en el monitor externo permanece en posición constante

#### Scenario: El tope de brillo no afecta a monitores DDC
- **WHEN** se solicita subir el brillo con el foco en un monitor externo gestionado por `ddcutil`
- **THEN** el brillo sube sin que se aplique el tope del panel interno

#### Scenario: La conexión en caliente no rompe el ámbito
- **WHEN** se conecta o desconecta un monitor externo con la sesión en marcha
- **THEN** la protección sigue activa en `eDP-1` y sigue ausente en el externo, sin requerir reinicio del shell

### Requirement: El ámbito se determina por identidad de pantalla, no por índice

La selección del panel protegido SHALL basarse en un identificador estable de la pantalla. MUST NOT depender del orden de enumeración de `Quickshell.screens`, que varía con la conexión en caliente.

#### Scenario: El orden de enumeración cambia
- **WHEN** se reordenan los monitores conectados de forma que cambie el índice de `eDP-1` en `Quickshell.screens`
- **THEN** la protección sigue aplicándose al panel interno y a ningún otro

#### Scenario: Sesión sin monitores externos
- **WHEN** solo está conectado `eDP-1`
- **THEN** la protección se aplica con normalidad y no se registra ningún error por monitores ausentes
