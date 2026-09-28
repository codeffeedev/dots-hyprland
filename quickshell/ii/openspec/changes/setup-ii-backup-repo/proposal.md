## Why

La configuración desplegada de illogical-impulse en `~/.config/quickshell/ii` no está bajo control de versiones: `~/.config` es un repo git cuya rama `master` no tiene ningún commit, y `.gitignore:2` (`/*`) excluye `quickshell/ii` explícitamente. Hoy existen 946 ficheros en disco, 43 de ellos divergentes del upstream (`origin/main` → `codeffeedev/dots-hyprland`), incluidos módulos propios como `modules/ii/bitwardenUnlock/`, `modules/settings/ScreenConfig.qml` y todo el directorio `openspec/`. Un `git clean`, una reinstalación de los dots o un error al editar QML los destruye sin posibilidad de recuperación.

Es necesario ahora porque el trabajo de protección OLED (change `add-oled-burn-in-protection`) va a modificar módulos del núcleo de ii — `modules/ii/bar/Bar.qml`, `modules/ii/verticalBar/VerticalBar.qml`, `services/Brightness.qml` — y sin respaldo previo no hay forma de revertir un cambio que rompa el shell.

## What Changes

- Se convierte `quickshell/ii` en contenido versionado del repo existente `~/.config`, en la rama huérfana `master`, dejando de estar excluido por `.gitignore`.
- Se modifica `~/.config/.gitignore` para reincluir la ruta `quickshell/ii` manteniendo intacta la allowlist actual del resto de `~/.config`.
- Se vendoriza `modules/common/widgets/shapes`: se elimina su fichero `.git` (un gitlink roto que apunta a `~/.config/.git/modules/...`, ruta inexistente) y sus ficheros pasan a commitearse como código normal del árbol.
- Se define y aplica un conjunto de exclusiones para artefactos que no deben versionarse (cachés, estado en ejecución, credenciales).
- Se incorpora al respaldo la configuración de usuario asociada sin la cual ii no restaura un escritorio funcional: `~/.config/illogical-impulse/config.json` y `~/.config/hypr/`.
- Se establece un procedimiento documentado de comparación contra upstream y de restauración.
- **BREAKING** (sobre las expectativas del repo, no sobre el runtime): `master` y `origin/main` quedan como historiales sin ancestro común y con rutas distintas para el mismo árbol (`quickshell/ii/` frente a `dots/.config/quickshell/ii/`). `git merge origin/main` y `git pull` dejan de ser operaciones válidas en este repo.

## Capabilities

### New Capabilities
- `ii-version-control`: qué parte del árbol desplegado queda versionada, bajo qué rama y con qué exclusiones; tratamiento del submódulo vendorizado.
- `ii-backup-restore`: garantías de respaldo y procedimiento verificable de restauración del escritorio a partir del repo.
- `upstream-divergence-tracking`: cómo se compara el árbol local contra `origin/main` pese a la diferencia de rutas y la ausencia de ancestro común.

### Modified Capabilities
<!-- Ninguna: openspec/specs/ está vacío, no hay especificaciones previas que alterar. -->

## Impact

Ficheros y sistemas afectados:

- `~/.config/.gitignore` — única modificación fuera del árbol de ii; queda fuera de `allowedEditRoots` de esta change, lo que exige confirmación explícita durante la aplicación.
- `~/.config/.git/` — pasa de 14 MB sin commits a contener el historial inicial; la rama `master` recibe su primer commit.
- `~/.config/quickshell/ii/modules/common/widgets/shapes/.git` — se elimina (gitlink roto, `fatal: no es un repositorio git`).
- `~/.config/quickshell/ii/modules/common/widgets/shapes/.gitignore` — se revisa; sus reglas dejarían de aplicarse a un submódulo y pasarían a afectar al repo padre.
- `~/.config/illogical-impulse/config.json` — pasa a estar versionado; contiene ajustes personales, entre ellos la ciudad de la meteorología.
- `~/.config/hypr/` — pasa a estar versionado; incluye el conflicto conocido entre `monitors.lua` y `custom/general.lua`, que esta change registra pero no resuelve.

Sin impacto en runtime: no se modifica ningún `.qml` ni se reinicia `qs`. El shell sigue ejecutándose durante toda la aplicación.

Dependencias: `git` (ya presente). No se añaden paquetes.

Riesgo principal: el repo `~/.config` apunta a un remote de terceros (`codeffeedev/dots-hyprland`). Un `git push` sin remote propio configurado fallaría por permisos, o —en el peor caso, si hubiera credenciales— publicaría configuración personal. La definición del remote de destino es requisito previo a cualquier push.
