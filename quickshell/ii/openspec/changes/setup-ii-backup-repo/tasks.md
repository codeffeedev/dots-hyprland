## 1. Preparación y línea base

- [ ] 1.1 Registrar el PID actual de `qs -c ii` en una nota temporal, para comparar al cerrar la change (spec `ii-version-control`, escenario "El shell sobrevive a la aplicación")
- [ ] 1.2 Generar el inventario de ficheros en disco bajo `~/.config/quickshell/ii` y guardarlo en `/tmp/opencode/` como línea base del recuento
- [ ] 1.3 Confirmar que `git status --porcelain` en `~/.config` sigue mostrando únicamente `?? .gitignore`; si hay más entradas, detenerse y revisar antes de continuar
- [ ] 1.4 Confirmar que `master` sigue sin commits (`git log` falla) — si ya tuviera historia, este plan debe revisarse por completo

## 2. Auditoría previa (resuelve preguntas abiertas del design)

- [ ] 2.1 Determinar qué ficheros escribe ii dentro de su propio árbol en ejecución: comparar el inventario de 1.2 con un nuevo listado tras varios minutos de uso, y localizar dónde persisten realmente `Persistent` y `KeyringStorage` (Open Question 1)
- [ ] 2.2 Leer `modules/common/widgets/shapes/.gitignore` y anotar si alguna de sus reglas excluiría ficheros que deben respaldarse (design D3)
- [ ] 2.3 Inspeccionar `~/.config/hypr/hyprland/` y decidir si es contenido regenerable de los dots o personalizado; registrar la decisión de alcance (Open Question 2)
- [ ] 2.4 Verificar que ningún fichero bajo las rutas a versionar contiene claves de API o material del llavero (spec `ii-version-control`, escenario "No se versionan credenciales")

## 3. Vendorización de `shapes`

- [ ] 3.1 Anotar el pin actual `e31ec4cb4ebf6a46b267f5c42eabf6874916fa16` y el origen `https://github.com/end-4/rounded-polygon-qmljs.git` para el mensaje del commit
- [ ] 3.2 Eliminar el fichero `modules/common/widgets/shapes/.git` (gitlink roto hacia `~/.config/.git/modules/...`, ruta inexistente)
- [ ] 3.3 Neutralizar o ajustar `shapes/.gitignore` según el resultado de 2.2, de modo que no excluya contenido del respaldo
- [ ] 3.4 Verificar que no queda ningún `.git` bajo `quickshell/ii` (spec `ii-version-control`, escenario "No queda gitlink")

## 4. Exclusiones

- [ ] 4.1 Crear `~/.config/quickshell/ii/.gitignore` con los patrones derivados de 2.1 y 2.4, cada uno con comentario que justifique su presencia (spec `ii-version-control`, escenario "Las exclusiones están declaradas, no son implícitas")
- [ ] 4.2 Añadir al `.gitignore` raíz los patrones `hypr/*.bak.*` y `hypr/*.old` para los 9 respaldos automáticos acumulados, sin borrarlos del disco (design Non-Goals)

## 5. Ampliación de la allowlist — FUERA DE `allowedEditRoots`, requiere confirmación del usuario

- [ ] 5.1 Confirmar con el usuario la edición de `~/.config/.gitignore`, fuera del ámbito declarado por OpenSpec para esta change (design, primer riesgo)
- [ ] 5.2 Añadir las negaciones para `/quickshell/` y `/quickshell/ii/` al `.gitignore` raíz, conservando intacto el bloque de allowlist alineado con upstream
- [ ] 5.3 Añadir las negaciones para `/illogical-impulse/` y `/hypr/` (design D4)
- [ ] 5.4 Verificar con `git check-ignore -v quickshell/ii` que ya no coincide ninguna regla (spec `ii-version-control`, escenario "La ruta deja de estar ignorada")
- [ ] 5.5 Verificar con `git status --porcelain` que aparecen las cuatro rutas previstas y ninguna ajena (spec `ii-version-control`, escenario "El resto de `~/.config` sigue ignorado")

## 6. Commit inicial

- [ ] 6.1 Preparar el índice con `quickshell/ii`, `illogical-impulse/config.json`, `hypr/` y el propio `.gitignore`
- [ ] 6.2 Contrastar `git ls-files quickshell/ii | wc -l` contra el inventario de 1.2 menos las exclusiones; investigar cualquier discrepancia antes de commitear (spec `ii-version-control`, escenario "Todos los ficheros del árbol quedan rastreados")
- [ ] 6.3 Comprobar que ninguna entrada del índice tiene modo `160000` (spec `ii-version-control`, escenario "Los ficheros se rastrean como blobs")
- [ ] 6.4 Crear el commit inicial en `master`, con mensaje que registre: procedencia y pin de `shapes`, el conflicto conocido entre `hypr/monitors.lua` y `hypr/custom/general.lua`, y su condición de estado previo al trabajo de protección OLED
- [ ] 6.5 Etiquetar el commit como punto de retorno identificable (spec `ii-backup-restore`, escenario "El punto de retorno es identificable")
- [ ] 6.6 Verificar que el diff del commit restringido a `*.qml` contiene solo adiciones, ninguna modificación de contenido (spec `ii-version-control`, escenario "No hay cambios de contenido en QML")

## 7. Verificación por restauración

- [ ] 7.1 Extraer `quickshell/ii` del commit inicial a un directorio temporal bajo `/tmp/opencode/`
- [ ] 7.2 Comparar recursivamente el árbol extraído con el desplegado; las únicas diferencias admisibles son las rutas excluidas en la fase 4 (spec `ii-backup-restore`, escenario "El árbol restaurado coincide con el desplegado")
- [ ] 7.3 Arrancar una instancia de Quickshell contra el árbol extraído y confirmar que no hay errores de importación QML ni ficheros ausentes (spec `ii-backup-restore`, escenario "El árbol restaurado arranca")
- [ ] 7.4 Confirmar que el PID de `qs -c ii` de la sesión coincide con el registrado en 1.1 y que la barra sigue visible (spec `ii-backup-restore`, escenario "La verificación no interfiere con la sesión activa")
- [ ] 7.5 Confirmar árbol de trabajo limpio en las rutas versionadas (spec `ii-backup-restore`, escenario "Árbol limpio al terminar")

## 8. Comparación con upstream

- [ ] 8.1 Confirmar que `origin/main` sigue resolviendo a un commit válido y que `git merge-base master origin/main` no devuelve ancestro (spec `upstream-divergence-tracking`, escenarios de referencia y ancestro)
- [ ] 8.2 Escribir un procedimiento versionado y repetible que liste ficheros solo-local, solo-upstream y divergentes, aplicando el prefijo `quickshell/ii/` en local y `dots/.config/quickshell/ii/` en upstream
- [ ] 8.3 Ejecutarlo y comprobar que identifica `modules/ii/bitwardenUnlock/`, `modules/settings/ScreenConfig.qml`, `openspec/` y `.opencode/` como exclusivos del árbol local (spec `upstream-divergence-tracking`, escenario "Se listan los ficheros exclusivamente locales")
- [ ] 8.4 Comprobar que señala los iconos ausentes bajo `assets/icons/` y marca `shapes` como diferencia esperada por vendorización (spec `upstream-divergence-tracking`, escenario "Se listan los ficheros ausentes en local")
- [ ] 8.5 Anotar junto al listado qué rutas son personalización deliberada y cuáles requieren revisión (spec `upstream-divergence-tracking`, escenario "El resultado distingue divergencia intencionada de deriva")

## 9. Documentación de restauración

- [ ] 9.1 Escribir el documento de restauración con el orden de pasos, indicando que `illogical-impulse/config.json` debe restaurarse antes del primer arranque del shell para que `Config.ready` no genere valores por defecto que lo sobrescriban (spec `ii-backup-restore`, escenario "El orden de restauración es explícito")
- [ ] 9.2 Enumerar en él los paquetes que el repo no contiene: `hyprland`, `hypridle`, `hyprlock`, `illogical-impulse-quickshell-git`, `brightnessctl`, `asusctl`, `qt6-declarative` (spec `ii-backup-restore`, escenario "Las dependencias externas están enumeradas")
- [ ] 9.3 Documentar que `shapes` está vendorizado, que no se obtiene por clonado y que una reinstalación de los dots lo declararía como submódulo y chocaría con el directorio existente (design, tercer riesgo)
- [ ] 9.4 Documentar la asimetría de rutas frente a upstream y la prohibición de `merge`, `rebase` y `pull` en este repo (spec `upstream-divergence-tracking`, escenario "La asimetría está documentada")
- [ ] 9.5 Dejar constancia de que el respaldo es local y no protege contra fallo de disco mientras no exista remote propio (spec `ii-backup-restore`, escenario "El destino queda registrado o pendiente")
- [ ] 9.6 Commitear la documentación y el procedimiento de comparación

## 10. Cierre

- [ ] 10.1 Confirmar que no se ha ejecutado ningún `git push origin` durante toda la change (spec `ii-backup-restore`, escenario "No se hace push al remote heredado")
- [ ] 10.2 Presentar al usuario la decisión pendiente sobre remote propio, privado o público, como paso posterior a esta change (design D6, Open Question 3)
