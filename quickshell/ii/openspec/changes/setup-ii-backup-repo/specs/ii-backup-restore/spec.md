## ADDED Requirements

### Requirement: El respaldo se verifica por restauración real, no por inspección

La change SHALL demostrar que el repositorio restaura un árbol de ii funcional. La verificación MUST consistir en materializar el contenido versionado en una ruta temporal y comprobarlo, y MUST NOT basarse únicamente en revisar la salida de `git status`.

#### Scenario: El árbol restaurado coincide con el desplegado
- **WHEN** se extrae el contenido de `quickshell/ii` desde el commit inicial a un directorio temporal y se compara recursivamente con `~/.config/quickshell/ii`
- **THEN** las únicas diferencias corresponden a rutas cubiertas por las exclusiones declaradas

#### Scenario: El árbol restaurado arranca
- **WHEN** se lanza una instancia de Quickshell apuntando al árbol restaurado en el directorio temporal
- **THEN** el proceso inicia sin errores de importación de QML y sin ficheros ausentes

#### Scenario: La verificación no interfiere con la sesión activa
- **WHEN** se ejecuta la verificación de restauración
- **THEN** la instancia `qs -c ii` de la sesión del usuario continúa en ejecución y la barra sigue visible

### Requirement: Existe un procedimiento de restauración documentado

El repositorio SHALL incluir un documento versionado que describa cómo reconstruir el escritorio desde cero a partir del repo. El documento MUST enumerar los paquetes requeridos que el repo no contiene y MUST indicar el orden de restauración.

#### Scenario: El documento existe y está versionado
- **WHEN** se ejecuta `git ls-files` desde `~/.config` buscando el documento de restauración
- **THEN** la ruta aparece rastreada

#### Scenario: Las dependencias externas están enumeradas
- **WHEN** se lee el documento de restauración
- **THEN** enumera al menos los paquetes `hyprland`, `hypridle`, `hyprlock`, `illogical-impulse-quickshell-git`, `brightnessctl` y `asusctl`, y advierte de que el árbol vendorizado `shapes` ya no se obtiene por clonado

#### Scenario: El orden de restauración es explícito
- **WHEN** se lee el documento de restauración
- **THEN** indica que `illogical-impulse/config.json` debe restaurarse antes del primer arranque del shell, para que `Config.ready` no genere valores por defecto que sobrescriban los respaldados

### Requirement: El commit inicial es un punto de retorno íntegro

El commit inicial SHALL representar el estado del escritorio en funcionamiento en el momento de aplicar la change, antes de cualquier modificación por protección OLED. El repositorio MUST tener el árbol de trabajo limpio respecto a las rutas versionadas al terminar la change.

#### Scenario: Árbol limpio al terminar
- **WHEN** se ejecuta `git status --porcelain` desde `~/.config` al completar la change
- **THEN** no aparece ninguna entrada modificada ni sin rastrear dentro de `quickshell/ii`, `illogical-impulse/` o `hypr/`

#### Scenario: El punto de retorno es identificable
- **WHEN** se consulta el historial de `master`
- **THEN** el commit inicial está etiquetado o su mensaje lo identifica como estado previo al trabajo de protección OLED

### Requirement: El remote de publicación es una decisión explícita

El repositorio SHALL NOT publicar contenido en el remote heredado `codeffeedev/dots-hyprland`. Antes de cualquier operación de push MUST existir un remote de destino distinto, elegido por el usuario.

#### Scenario: No se hace push al remote heredado
- **WHEN** se completa la change
- **THEN** no se ha ejecutado ningún `git push origin`

#### Scenario: El destino queda registrado o pendiente
- **WHEN** se inspecciona la configuración de remotes al terminar
- **THEN** o bien existe un remote adicional designado para el respaldo, o bien la documentación de restauración deja constancia de que el repo es de ámbito local hasta que se defina uno
