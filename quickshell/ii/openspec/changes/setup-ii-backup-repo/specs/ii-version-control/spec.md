## ADDED Requirements

### Requirement: El árbol desplegado de ii queda versionado en el repo `~/.config`

El árbol `~/.config/quickshell/ii` SHALL estar completamente rastreado por el repositorio git cuya raíz es `~/.config`, en la rama `master`. La allowlist existente en `~/.config/.gitignore` MUST seguir excluyendo el resto de `~/.config` salvo las rutas que esta especificación reincluye explícitamente.

#### Scenario: La ruta deja de estar ignorada
- **WHEN** se ejecuta `git check-ignore -v quickshell/ii` desde `~/.config`
- **THEN** el comando termina con código de salida distinto de cero y no imprime ninguna regla coincidente

#### Scenario: Todos los ficheros del árbol quedan rastreados
- **WHEN** se ejecuta `git ls-files quickshell/ii | wc -l` desde `~/.config` tras el commit inicial
- **THEN** el recuento es igual al número de ficheros presentes en disco bajo `quickshell/ii` menos los excluidos por la regla de exclusiones definida en esta capacidad

#### Scenario: El resto de `~/.config` sigue ignorado
- **WHEN** se ejecuta `git status --porcelain` desde `~/.config` tras el commit inicial
- **THEN** la salida no contiene ninguna ruta ajena a `quickshell/ii`, `illogical-impulse/`, `hypr/` o `.gitignore`

### Requirement: El submódulo `shapes` queda vendorizado

El directorio `modules/common/widgets/shapes` SHALL versionarse como ficheros normales del árbol, no como submódulo. El fichero `.git` que actúa de gitlink roto MUST eliminarse antes del commit inicial, y el repo MUST NOT declarar ninguna entrada en `.gitmodules` para esa ruta.

#### Scenario: No queda gitlink
- **WHEN** se inspecciona `modules/common/widgets/shapes` tras aplicar la change
- **THEN** no existe ningún fichero ni directorio `.git` en esa ruta

#### Scenario: Los ficheros se rastrean como blobs
- **WHEN** se ejecuta `git ls-files -s quickshell/ii/modules/common/widgets/shapes` desde `~/.config`
- **THEN** ninguna entrada tiene el modo `160000` y todas tienen modo de fichero regular

#### Scenario: La procedencia queda registrada
- **WHEN** se consulta el mensaje del commit que introduce el directorio vendorizado
- **THEN** el mensaje indica el origen `https://github.com/end-4/rounded-polygon-qmljs.git` y el commit fijado `e31ec4cb4ebf6a46b267f5c42eabf6874916fa16`

### Requirement: Las exclusiones impiden versionar estado y secretos

El repositorio SHALL excluir los artefactos que no forman parte de la configuración fuente. Como mínimo MUST excluirse el estado en ejecución, las cachés, las miniaturas generadas y cualquier fichero que contenga credenciales o claves de API.

#### Scenario: No se versionan credenciales
- **WHEN** se ejecuta `git ls-files` desde `~/.config` tras el commit inicial
- **THEN** ninguna ruta listada corresponde a almacenamiento de claves de API o material del llavero

#### Scenario: Las exclusiones están declaradas, no son implícitas
- **WHEN** se inspecciona la configuración de exclusiones tras aplicar la change
- **THEN** cada patrón de exclusión aparece escrito en un fichero `.gitignore` versionado, acompañado de un comentario que justifica su presencia

### Requirement: La configuración de usuario asociada queda respaldada

El repositorio SHALL versionar `~/.config/illogical-impulse/config.json` y el contenido de `~/.config/hypr/`, por ser la configuración sin la cual el árbol de ii no reproduce el escritorio en funcionamiento.

#### Scenario: El config.json queda rastreado
- **WHEN** se ejecuta `git ls-files illogical-impulse/config.json` desde `~/.config`
- **THEN** la salida contiene exactamente esa ruta

#### Scenario: Las configuraciones Lua de Hyprland quedan rastreadas
- **WHEN** se ejecuta `git ls-files hypr` desde `~/.config`
- **THEN** la salida incluye `hypr/hyprland.lua`, `hypr/custom/general.lua`, `hypr/monitors.lua` y `hypr/hypridle.conf`

#### Scenario: Los respaldos automáticos antiguos no se versionan
- **WHEN** se ejecuta `git ls-files hypr` desde `~/.config`
- **THEN** la salida no contiene ninguna ruta terminada en `.old` ni coincidente con el patrón `*.bak.*`

### Requirement: El runtime del shell no se ve afectado

La aplicación de esta change SHALL NOT modificar ningún fichero `.qml`, `.js` o script ejecutado por el shell, salvo la eliminación del gitlink `.git` del directorio vendorizado. El proceso `qs` MUST seguir en ejecución sin recarga forzada durante todo el procedimiento.

#### Scenario: El shell sobrevive a la aplicación
- **WHEN** se completa la change
- **THEN** el PID del proceso `qs -c ii` es el mismo que antes de comenzar

#### Scenario: No hay cambios de contenido en QML
- **WHEN** se revisa el diff del commit inicial restringido a ficheros `*.qml`
- **THEN** todas las entradas son adiciones de ficheros previamente no rastreados, sin ninguna modificación de contenido
