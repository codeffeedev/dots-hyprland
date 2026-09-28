## Context

Estado verificado del sistema en el momento de redactar este diseño:

| Hecho | Valor observado |
|---|---|
| Raíz del repo que contiene ii | `~/.config` (`git rev-parse --show-toplevel`) |
| Rama actual | `master`, **sin ningún commit** (`fatal: tu rama actual 'master' no tiene ningún commit todavía`) |
| Remote | `origin` → `https://github.com/codeffeedev/dots-hyprland` |
| Referencias remotas | `origin/main` presente, último commit `c04b0bbc` |
| Exclusión de ii | `.gitignore:2` → `/*` (allowlist); `git check-ignore` confirma `quickshell/ii` ignorado |
| Ficheros rastreados de ii | 0 |
| Único cambio pendiente | `?? .gitignore` |
| Tamaño del árbol ii | 5,9 MB, 946 ficheros |
| Árbol ii en upstream | `dots/.config/quickshell/ii/`, 903 ficheros |
| Submódulo `shapes` | declarado en `.gitmodules` de upstream → `end-4/rounded-polygon-qmljs`, pin `e31ec4cb4ebf6a46b267f5c42eabf6874916fa16`, modo `160000` |
| Estado local de `shapes` | fichero `.git` con `gitdir: ../../../../../../../../.git/modules/dots/.config/quickshell/ii/...`; el destino `~/.config/.git/modules` **no existe** → submódulo roto |
| Divergencia | 43 ficheros solo en local, 5 entradas solo en upstream |
| Shell en ejecución | `qs -c ii` (PID 2196), `hypridle` (PID 2199) |

El repositorio está a medio configurar: alguien preparó `~/.config` como checkout de un fork de dots-hyprland, escribió una allowlist alineada con la estructura de `origin/main`, y nunca commiteó. El resultado es un repo con referencias remotas útiles pero sin historia propia, y con el árbol realmente en uso completamente fuera de su control.

Restricción de herramienta: `openspec status` declara `allowedEditRoots: ["/home/as/.config/quickshell/ii"]`. Dos ficheros que esta change necesita tocar —`~/.config/.gitignore` y `~/.config/illogical-impulse/config.json`— quedan fuera de ese ámbito.

## Goals / Non-Goals

**Goals:**

- Dejar el árbol desplegado de ii bajo control de versiones en el repo `~/.config`, rama `master`, con un commit inicial que sirva de punto de retorno antes del trabajo de protección OLED.
- Resolver el submódulo `shapes` roto por vendorización, de forma que el respaldo sea autocontenido y restaurable sin acceso a la red.
- Incluir la configuración de usuario (`illogical-impulse/config.json`, `hypr/`) sin la cual el árbol de ii no reproduce el escritorio observado.
- Conservar `origin/main` como referencia consultable y documentar cómo comparar pese a la asimetría de rutas.
- Verificar el respaldo restaurándolo, no inspeccionándolo.

**Non-Goals:**

- No se resuelve el conflicto entre `~/.config/hypr/monitors.lua` (eDP-1 en `240x560`) y `~/.config/hypr/custom/general.lua` (eDP-1 en `0x0`). Se versiona el conflicto tal cual está, y se anota. Corregirlo es otra change.
- No se limpian los 9 ficheros `.bak.*` / `.old` de `~/.config/hypr/`. Se excluyen del versionado, no se borran del disco.
- No se modifica ningún QML ni se toca la protección OLED. Eso es `add-oled-burn-in-protection`.
- No se versiona el resto de `~/.config` (Brave, mise, etc.). La allowlist se amplía con precisión quirúrgica.
- No se automatiza el respaldo (cron, hooks, servicio systemd). Commits manuales.
- No se hace push a ningún remote en esta change.

## Decisions

### D1 — Rama `master` huérfana con el árbol en su ruta desplegada

El árbol se commitea en `quickshell/ii/`, la ruta real en disco, no en `dots/.config/quickshell/ii/` como hace upstream.

*Por qué:* la raíz del repo es `~/.config`, que es el directorio desplegado. Replicar la estructura de upstream exigiría o bien duplicar 5,9 MB en `dots/`, o bien enlaces simbólicos entre ambas rutas. Lo primero desincroniza el respaldo del árbol vivo en cuanto se edite un QML; lo segundo es frágil y confunde a `qs`, que sigue enlaces pero no los recarga igual.

*Alternativa descartada:* reestructurar `~/.config` para encajar en el layout de upstream. Se descarta porque el valor del repo aquí es respaldar lo que se ejecuta, y upstream es un repo de *fuentes de dotfiles*, no de configuración desplegada. Son cosas distintas y forzar la equivalencia daña la primera para obtener una compatibilidad de merge que igualmente no funcionaría.

*Consecuencia aceptada:* `master` y `origin/main` no tienen ancestro común y ubican el mismo contenido en prefijos distintos. `git merge`, `git rebase` y `git pull` quedan prohibidos en este repo. Es una pérdida real: actualizar ii desde upstream pasa a ser un proceso manual de comparación y copia.

### D2 — Ampliación quirúrgica de la allowlist

`.gitignore` empieza con `/*`, que ignora toda entrada de primer nivel. Git no desciende en directorios ignorados, así que reincluir una ruta anidada exige reincluir primero su directorio padre. Se añaden negaciones para `/quickshell/`, `/illogical-impulse/` y `/hypr/`, manteniendo el bloque existente alineado con upstream sin tocarlo.

*Por qué no `git add -f`:* forzar el añadido rastrea los ficheros pero deja la regla de ignorado en pie. Cualquier fichero nuevo creado después dentro de ii seguiría invisible para `git status`, que es justamente el fallo que esta change existe para eliminar.

*Verificación:* `git check-ignore -v quickshell/ii` debe dejar de coincidir. `~/.config/quickshell/` solo contiene `ii`, pero la negación se escribe explícita sobre `ii` para que un futuro `qs -c otro` no entre al respaldo por accidente.

### D3 — Vendorizar `shapes` en vez de re-declarar el submódulo

Se elimina el fichero `.git` (gitlink roto) y los 21 ficheros pasan a commitearse como blobs normales. La procedencia (`end-4/rounded-polygon-qmljs`, pin `e31ec4cb`) se registra en el mensaje del commit.

*Por qué:* el propósito del repo es restaurar. Un submódulo convierte la restauración en dependiente de red y de que el repo remoto siga existiendo; `rounded-polygon-qmljs` es un repo pequeño de un solo autor. La vendorización hace el respaldo autocontenido, que es exactamente lo que se pide de una copia de seguridad.

*Coste aceptado:* se pierde la trazabilidad automática de actualizaciones de shapes. Como el pin ya estaba fijo en `e31ec4cb` y nadie lo actualiza, el coste es teórico.

*Detalle a resolver:* `shapes/.gitignore` deja de ser el `.gitignore` de un submódulo y pasa a aplicarse dentro del repo padre. Hay que leer su contenido antes de commitear: si excluye ficheros que sí queremos respaldar, se neutraliza.

### D4 — Ampliar el alcance a `illogical-impulse/config.json` y `hypr/`

*Por qué:* el árbol de ii es código; el escritorio observado es código **más** configuración. `config.json` contiene el borde de la barra, la ruta del wallpaper, la posición del reloj, la ciudad de la meteorología y la lista de apps ancladas. Sin él, restaurar ii produce un ii por defecto, no *este* escritorio. `hypr/` contiene los monitores, los keybinds y el escalonado de `hypridle` ya ajustado para OLED. Un respaldo de ii sin estos dos no cumple su función.

*Alternativa descartada:* limitarse estrictamente a `quickshell/ii`. Es lo que pidió literalmente el enunciado, pero produce un respaldo que no restaura. Se amplía y se deja aislado en su propia fase de tareas, de modo que recortarlo sea trivial si se prefiere.

*Riesgo asumido:* `config.json` contiene datos personales de bajo impacto (ciudad `Zaragoza, España`). Relevante solo si el repo se publica; ver D6.

### D5 — Exclusiones declaradas, no implícitas

Se escribe un `.gitignore` dentro de `quickshell/ii/` para el estado en ejecución, y se añaden patrones para `hypr/*.bak.*` y `hypr/*.old`. Cada patrón lleva comentario justificativo.

*Por qué dentro de ii y no todo en el `.gitignore` raíz:* el raíz es la allowlist heredada de upstream; mezclar reglas de contenido con reglas de estructura hace ilegibles ambas.

*Punto abierto:* hay que auditar qué escribe ii dentro de su propio árbol en runtime antes de fijar la lista. Lo conocido es que `Persistent` y `KeyringStorage` persisten estado, pero su ruta real (`~/.local/state`, `~/.cache` o dentro del árbol) debe confirmarse en tiempo de aplicación, no suponerse aquí.

### D6 — Sin push; remote de destino pendiente

`origin` apunta a un repositorio de terceros. Esta change no ejecuta ningún push. Definir un remote propio se deja como paso posterior, con decisión explícita del usuario sobre visibilidad pública o privada.

*Por qué importa:* un push accidental a `origin` fallaría por permisos en el caso normal, pero si hubiera credenciales con acceso publicaría la configuración personal del usuario. El coste de no hacer push ahora es nulo; el de equivocarse es irreversible.

## Risks / Trade-offs

- **Edición fuera de `allowedEditRoots`** → `~/.config/.gitignore` y `~/.config/illogical-impulse/config.json` caen fuera del ámbito declarado por OpenSpec para esta change. Mitigación: las tareas que salen del ámbito se marcan como tales y requieren confirmación del usuario antes de ejecutarse.

- **`shapes/.gitignore` oculta ficheros al vendorizar** → al dejar de ser submódulo, sus reglas aplican al repo padre y podrían excluir silenciosamente ficheros del respaldo. Mitigación: leer el fichero y comprobar el recuento de ficheros rastreados frente a los presentes en disco antes de dar por bueno el commit.

- **La vendorización rompe una futura actualización de upstream** → si algún día se reinstalan los dots, `shapes` volverá a ser submódulo y chocará con el directorio vendorizado. Mitigación: documentarlo en el procedimiento de restauración.

- **El commit inicial fotografía un conflicto de monitores** → `monitors.lua` y `custom/general.lua` declaran eDP-1 en posiciones distintas. Se respalda un estado con un defecto conocido. Mitigación: anotarlo en el mensaje del commit para que quien restaure no lo confunda con daño de la restauración.

- **Falso sentido de seguridad** → un repo local en `~/.config/.git` no protege contra fallo de disco ni borrado de `$HOME`. Mitigación: el procedimiento de restauración debe indicar explícitamente que el respaldo no es externo hasta que se configure un remote.

- **Datos personales en el respaldo** → `config.json` y el historial de wallpapers contienen información de uso. Mitigación: repo local por defecto; decisión de publicación diferida y explícita.

- **5,9 MB de binarios (SVG, PNG) en el historial** → cada actualización de assets crece el repo de forma no compresible. Mitigación: aceptable a esta escala; se revisa si el `.git` supera un umbral razonable.

## Migration Plan

1. **Preparación** — Registrar el PID actual de `qs` para verificar al final que no se ha reiniciado. Inventariar ficheros en disco bajo `quickshell/ii` para comparar después con `git ls-files`.
2. **Auditoría de exclusiones** — Determinar qué escribe ii dentro de su árbol en ejecución y leer `shapes/.gitignore`. Fijar la lista de exclusiones con esos datos.
3. **Vendorización** — Eliminar `shapes/.git`. Neutralizar `shapes/.gitignore` si excluye contenido necesario.
4. **Allowlist** — Ampliar `~/.config/.gitignore`. Verificar con `git check-ignore` y con `git status --porcelain` que aparece lo esperado y nada más.
5. **Commit inicial** — Un único commit en `master` con el árbol completo, mensaje que registre la procedencia de `shapes`, el conflicto de monitores y su condición de punto previo al trabajo OLED. Etiquetar.
6. **Verificación por restauración** — Extraer a directorio temporal, comparar recursivamente, arrancar una instancia de Quickshell contra el árbol extraído. Confirmar que la sesión activa sigue intacta.
7. **Documentación** — Escribir el procedimiento de restauración y la guía de comparación con upstream. Commitear.

**Rollback:** en cualquier punto antes del paso 5, `git reset` y revertir `.gitignore` deja el sistema exactamente como estaba; no se ha modificado nada que el shell lea. Tras el paso 5, el rollback es `git update-ref -d refs/heads/master` más la reversión de `.gitignore`. El único cambio no reversible por git es la eliminación de `shapes/.git`, que ya estaba roto y no tenía función; si se necesitase recuperar, se re-clona desde `end-4/rounded-polygon-qmljs` en el pin `e31ec4cb`.

## Open Questions

1. ¿Qué escribe ii dentro de su propio árbol durante la ejecución? Determina la lista de exclusiones. Se resuelve en el paso 2, no antes.
2. ¿Se versiona `~/.config/hypr/` completo o solo `custom/` más los ficheros de nivel superior? El directorio `hypr/hyprland/` puede provenir íntegro de los dots y ser regenerable. Decisión tras inspeccionar su procedencia.
3. ¿Remote propio privado o repo local únicamente? Diferido a después de esta change.
4. ¿El directorio `.opencode/` de ii se respalda o se considera herramienta separada? Por defecto se incluye: es divergencia local y su pérdida costaría rehacerlo.
