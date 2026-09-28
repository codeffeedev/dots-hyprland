## 1. Prerrequisitos

- [ ] 1.1 Verificar que la change `setup-ii-backup-repo` está aplicada y que `git status --porcelain` en `~/.config` no muestra cambios pendientes en `quickshell/ii`; si no lo está, detenerse (proposal, Impact)
- [ ] 1.2 Registrar el PID de `qs -c ii` y la etiqueta del punto de retorno, para poder restaurar si el shell queda inoperativo
- [ ] 1.3 Comprobar que `qmlformat` está disponible para validar sintaxis antes de guardar cambios en QML (design, primer riesgo)

## 2. Fuente de verdad de la configuración de monitores

- [ ] 2.1 Presentar al usuario la disyuntiva entre consolidar en `~/.config/hypr/monitors.lua` (autogenerado por QuickConfig, riesgo de sobrescritura) o en `~/.config/hypr/custom/general.lua` (riesgo de reaparición del conflicto al regenerar), y recoger su decisión (design D6, Open Question 2)
- [ ] 2.2 Retirar la declaración `hl.monitor` de `eDP-1` del fichero no elegido, dejando un comentario que indique dónde se ha trasladado (spec `hyprland-config-source-of-truth`, escenario "El fichero desplazado no queda silenciosamente vacío")
- [ ] 2.3 Añadir en el fichero elegido un comentario que lo identifique como fuente de verdad y advierta del riesgo de regeneración automática (spec `hyprland-config-source-of-truth`, escenario "El comentario existe")
- [ ] 2.4 Verificar que solo queda una declaración de `eDP-1` en todo `~/.config/hypr/` (spec `hyprland-config-source-of-truth`, escenario "Una sola declaración")
- [ ] 2.5 Recargar Hyprland y confirmar que `hyprctl monitors` sigue informando `2880x1800@90` y escala `1.8` (spec `hyprland-config-source-of-truth`, escenario "La geometría se preserva")
- [ ] 2.6 Confirmar con ventanas abiertas que ninguna cambia de espacio de trabajo ni queda fuera del área visible (spec `hyprland-config-source-of-truth`, escenario "Las ventanas abiertas no se recolocan")
- [ ] 2.7 Commitear la resolución del conflicto como cambio independiente

## 3. Inventario de elementos permanentes

- [ ] 3.1 Recorrer una sesión de trabajo normal y registrar cada elemento visible que no cambia de posición, con su superficie aproximada y luminosidad relativa (spec `oled-safe-theming`, escenario "El inventario cubre los elementos conocidos")
- [ ] 3.2 Incluir explícitamente barra, las cuatro esquinas de `ScreenCorners`, dock, reloj del fondo y bordes de ventana de Hyprland
- [ ] 3.3 Asignar a cada entrada una contramedida prevista o una justificación de por qué no se aplica ninguna (spec `oled-safe-theming`, escenario "Cada entrada tiene resolución")
- [ ] 3.4 Fijar el umbral de luminosidad y saturación que se usará como criterio en la fase 9, y dejarlo registrado en el inventario
- [ ] 3.5 Commitear el inventario

## 4. Opciones de configuración

- [ ] 4.1 Añadir en `modules/common/Config.qml` las opciones de desplazamiento de píxeles: amplitud, intervalo y activación, con valores por defecto que no alteren el comportamiento actual (spec `static-element-pixel-shift`, escenario "Instalación limpia sin cambio de comportamiento")
- [ ] 4.2 Añadir la opción de tope de brillo del panel interno, con valor por defecto que no recorte el rango actual
- [ ] 4.3 Verificar que amplitud cero no programa ningún temporizador (spec `static-element-pixel-shift`, escenario "Amplitud cero equivale a desactivado")
- [ ] 4.4 Recargar el shell y confirmar que no hay cambio de comportamiento observable respecto al estado previo
- [ ] 4.5 Commitear las opciones de configuración

## 5. Desplazamiento de la barra horizontal

- [ ] 5.1 Ampliar el tamaño implícito de la `PanelWindow` de `Bar.qml` con el margen de desplazamiento, manteniendo el cálculo de `exclusiveZone` sobre `Appearance.sizes.baseBarHeight` sin incluir ese margen (design D1)
- [ ] 5.2 Implementar el desplazamiento periódico del contenido dentro del margen, con transición animada y no por salto (spec `static-element-pixel-shift`, escenario "La transición es animada")
- [ ] 5.3 Hacer que `mask: Region { item: hoverMaskRegion }` siga el contenido desplazado, para no desalinear los objetivos de pulsación (design D1, punto pendiente)
- [ ] 5.4 Restringir el desplazamiento a `eDP-1` por identificador de pantalla, siguiendo el patrón de filtrado por `screen.name` ya presente en `Bar.qml` (design D4)
- [ ] 5.5 Verificar que el área reservada del monitor es idéntica antes y después de varios desplazamientos (spec `static-element-pixel-shift`, escenario "La zona exclusiva no varía")
- [ ] 5.6 Verificar con una ventana en mosaico adyacente que su geometría en `hyprctl clients` no cambia (spec `static-element-pixel-shift`, escenario "Una ventana en mosaico no se mueve")
- [ ] 5.7 Verificar que pulsar un botón de la barra tras un desplazamiento activa ese botón y no un vecino (spec `static-element-pixel-shift`, escenario "Los botones responden donde se ven")
- [ ] 5.8 Verificar que con `bar.autoHide.enable` activo la barra sigue ocultándose y revelándose con puntero y con Super (spec `static-element-pixel-shift`, escenario "El modo de auto-ocultado sigue funcionando")
- [ ] 5.9 Verificar que no hay parpadeo, cambio de tamaño, reordenación ni recorte de elementos (spec `static-element-pixel-shift`, escenario "No hay parpadeo ni reflujo de disposición")
- [ ] 5.10 Commitear el desplazamiento de la barra horizontal

## 6. Desplazamiento de la barra vertical

- [ ] 6.1 Trasladar la implementación a `modules/ii/verticalBar/VerticalBar.qml`, sobre `baseVerticalBarWidth` e `implicitWidth`
- [ ] 6.2 Verificar el desplazamiento en las cuatro orientaciones alternando `bar.bottom` y `bar.vertical` (spec `static-element-pixel-shift`, escenario "Funciona en las cuatro orientaciones")
- [ ] 6.3 Verificar que el recorrido nunca excede el margen configurado (spec `static-element-pixel-shift`, escenario "El recorrido está acotado")
- [ ] 6.4 Repetir en orientación vertical las comprobaciones de zona exclusiva, pulsación y auto-ocultado de la fase 5
- [ ] 6.5 Commitear el desplazamiento de la barra vertical

## 7. Desplazamiento del reloj del fondo

- [ ] 7.1 Implementar en `modules/ii/background/widgets/AbstractBackgroundWidget.qml` el desplazamiento como desviación sobre la posición calculada, sin anular `placementStrategy` (spec `static-element-pixel-shift`, escenario "La colocación configurada se respeta como origen")
- [ ] 7.2 Verificar que el reloj cambia de posición sin necesidad de cambiar el wallpaper (spec `static-element-pixel-shift`, escenario "El reloj cambia de posición sin cambiar el wallpaper")
- [ ] 7.3 Verificar que con `placementStrategy: "free"` el arrastre manual sigue funcionando y la posición arrastrada pasa a ser el origen (spec `static-element-pixel-shift`, escenario "El arrastre manual sigue disponible")
- [ ] 7.4 Commitear el desplazamiento del reloj del fondo

## 8. Tope de brillo

- [ ] 8.1 Implementar el recorte en `services/Brightness.qml`, aplicándolo a toda vía de subida: teclas de función, control de la interfaz y llamadas programáticas (spec `oled-brightness-cap`, escenario "La subida repetida se detiene en el tope")
- [ ] 8.2 Aplicar el tope al arrancar el shell si el brillo del panel lo excede (spec `oled-brightness-cap`, escenario "El tope se aplica al arrancar")
- [ ] 8.3 Restringir el recorte al monitor interno respaldado por `intel_backlight`, dejando intacto el rango de los monitores DDC (spec `oled-brightness-cap`, escenario "Un monitor DDC alcanza su máximo")
- [ ] 8.4 Verificar que el OSD nunca muestra un valor que el tope ha impedido alcanzar (spec `oled-brightness-cap`, escenario "El OSD no muestra un valor inalcanzable")
- [ ] 8.5 Verificar que con gamma por debajo de 100 la subida sigue restaurando primero la gamma (spec `oled-brightness-cap`, escenario "La gamma se restaura antes que el brillo")
- [ ] 8.6 Verificar que con brillo a cero la bajada sigue reduciendo la gamma (spec `oled-brightness-cap`, escenario "La reducción por debajo de cero sigue bajando la gamma")
- [ ] 8.7 Confirmar que no se ha añadido ningún script envoltorio de `brightnessctl` fuera del servicio (spec `oled-brightness-cap`, escenario "No se introducen scripts envoltorio")
- [ ] 8.8 Consultar al usuario el valor del tope, sabiendo que el panel está hoy al 79 % de 400 (design, Open Question 4)
- [ ] 8.9 Commitear el tope de brillo

## 9. Ajustes de tema según el inventario

- [ ] 9.1 Presentar al usuario la decisión sobre `appearance.fakeScreenRounding` como cambio estético visible antes de modificarlo (spec `oled-safe-theming`, escenario "El cambio estético es explícito")
- [ ] 9.2 Registrar la decisión tomada sobre las cuatro esquinas, con su motivo (spec `oled-safe-theming`, escenario "La decisión queda registrada")
- [ ] 9.3 Ajustar el color de borde activo de ventana por debajo del umbral fijado en 3.4, conservando `border_size = 1` y `dim_inactive = true` (spec `oled-safe-theming`, escenarios de bordes)
- [ ] 9.4 Moderar los colores de primer plano de los indicadores permanentes de la barra, sin usar blanco puro ni luminosidad máxima (spec `oled-safe-theming`, escenario "Ningún indicador usa el nivel de luminosidad máximo")
- [ ] 9.5 Verificar que el reloj y los indicadores siguen leyéndose sin esfuerzo (spec `oled-safe-theming`, escenario "El contenido sigue siendo legible")
- [ ] 9.6 Cambiar el wallpaper para forzar la regeneración de la paleta Material3 y confirmar que los ajustes de moderación se mantienen (spec `oled-safe-theming`, escenario "El tema derivado del wallpaper sigue funcionando")
- [ ] 9.7 Confirmar que `hypridle.conf` no se ha modificado y que ningún umbral se ha relajado (spec `oled-safe-theming`, escenario "Los umbrales no se relajan")
- [ ] 9.8 Comprobar que tras el umbral de inactividad el panel se apaga realmente y restaura brillo al reanudar (spec `oled-safe-theming`, escenario "El apagado del panel sigue siendo efectivo")
- [ ] 9.9 Commitear los ajustes de tema

## 10. Verificación de ámbito con monitor externo

- [ ] 10.1 Conectar un monitor externo y comprobar que su instancia de la barra permanece inmóvil (spec `internal-panel-scoping`, escenario "La barra externa no se desplaza")
- [ ] 10.2 Comprobar que el tope de brillo no se aplica con el foco en el monitor externo (spec `internal-panel-scoping`, escenario "El tope de brillo no afecta a monitores DDC")
- [ ] 10.3 Conectar y desconectar en caliente y confirmar que la protección sigue en `eDP-1` y ausente en el externo, sin reiniciar el shell (spec `internal-panel-scoping`, escenario "La conexión en caliente no rompe el ámbito")
- [ ] 10.4 Reordenar los monitores para alterar el índice de `eDP-1` en `Quickshell.screens` y confirmar que la protección no se desplaza de panel (spec `internal-panel-scoping`, escenario "El orden de enumeración cambia")
- [ ] 10.5 Desconectar los externos y confirmar que no se registra ningún error por monitores ausentes (spec `internal-panel-scoping`, escenario "Sesión sin monitores externos")

## 11. Ajuste final y cierre

- [ ] 11.1 Tras varios días de uso real, fijar los valores definitivos de amplitud e intervalo de desplazamiento (design, Open Question 1)
- [ ] 11.2 Evaluar si el desplazamiento debe pausarse mientras el panel está atenuado o apagado por `hypridle`, y aplicar la decisión (design, Open Question 5)
- [ ] 11.3 Verificar que los ajustes de amplitud e intervalo surten efecto en caliente sin reiniciar el shell (spec `static-element-pixel-shift`, escenario "Los ajustes se aplican en caliente")
- [ ] 11.4 Registrar en el procedimiento de comparación con upstream creado por `setup-ii-backup-repo` los puntos de inserción de esta change, para facilitar futuras actualizaciones (design, cuarto riesgo)
- [ ] 11.5 Dejar constancia de que la protección no cubre el contenido de las aplicaciones, solo el shell (design, último riesgo)
