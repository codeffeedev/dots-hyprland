## ADDED Requirements

### Requirement: La barra desplaza su contenido periódicamente

La barra SHALL desplazar el contenido que dibuja dentro de un margen acotado, de forma periódica, en las cuatro orientaciones soportadas por ii (`bar.bottom` combinado con `bar.vertical`). El desplazamiento MUST aplicarse tanto a `modules/ii/bar/Bar.qml` como a `modules/ii/verticalBar/VerticalBar.qml`.

#### Scenario: El contenido cambia de posición con el tiempo
- **WHEN** se observa la posición de un elemento de la barra a lo largo de varios intervalos de desplazamiento
- **THEN** la posición ocupa valores distintos dentro del margen configurado, no un valor constante

#### Scenario: Funciona en las cuatro orientaciones
- **WHEN** se alterna `bar.bottom` y `bar.vertical` cubriendo las combinaciones superior, inferior, izquierda y derecha
- **THEN** el desplazamiento sigue activo en cada una, sobre el eje que corresponde

#### Scenario: El recorrido está acotado
- **WHEN** se mide la posición del contenido durante un periodo prolongado
- **THEN** ningún valor excede el margen configurado respecto a la posición de reposo

### Requirement: El desplazamiento no recoloca las ventanas

La zona exclusiva de layer-shell SHALL permanecer constante durante el desplazamiento. Las ventanas gestionadas por Hyprland MUST NOT cambiar de geometría como consecuencia del movimiento de la barra.

#### Scenario: La zona exclusiva no varía
- **WHEN** se consulta el área reservada del monitor antes y después de varios desplazamientos
- **THEN** el valor reservado es idéntico

#### Scenario: Una ventana en mosaico no se mueve
- **WHEN** hay una ventana en mosaico ocupando el espacio adyacente a la barra y se produce un desplazamiento
- **THEN** la geometría de la ventana informada por `hyprctl clients` no cambia

#### Scenario: El modo de auto-ocultado sigue funcionando
- **WHEN** `bar.autoHide.enable` está activo y se produce un desplazamiento
- **THEN** la barra sigue ocultándose y revelándose con el puntero y con la tecla Super según su configuración

### Requirement: El desplazamiento no degrada la interacción

Las regiones de entrada de la barra SHALL seguir el contenido desplazado. Los objetivos de pulsación MUST permanecer alineados con lo que se dibuja.

#### Scenario: Los botones responden donde se ven
- **WHEN** se pulsa un botón de la barra tras un desplazamiento
- **THEN** se activa ese botón y no un vecino

#### Scenario: El hover de revelado sigue activo
- **WHEN** el puntero se acerca al borde de la pantalla tras un desplazamiento
- **THEN** la región de hover responde igual que antes del desplazamiento

### Requirement: El desplazamiento es imperceptible en uso normal

La transición entre posiciones SHALL ser gradual, no un salto instantáneo. El movimiento MUST NOT llamar la atención del usuario durante el trabajo.

#### Scenario: La transición es animada
- **WHEN** se produce un cambio de posición
- **THEN** el contenido transita de forma continua entre la posición anterior y la nueva

#### Scenario: No hay parpadeo ni reflujo de disposición
- **WHEN** se produce un desplazamiento
- **THEN** los elementos de la barra no cambian de tamaño, no se reordenan y no se recortan

### Requirement: El reloj del fondo también se desplaza

El reloj digital del fondo, hoy colocado por `placementStrategy` y por tanto estático mientras no cambie el wallpaper, SHALL recibir un desplazamiento periódico equivalente al de la barra.

#### Scenario: El reloj cambia de posición sin cambiar el wallpaper
- **WHEN** se observa el reloj del fondo durante varios intervalos con el mismo wallpaper
- **THEN** su posición varía dentro del margen configurado

#### Scenario: La colocación configurada se respeta como origen
- **WHEN** está activa una `placementStrategy` distinta de `free`
- **THEN** el desplazamiento se aplica como desviación respecto a la posición que esa estrategia calcula, sin anularla

#### Scenario: El arrastre manual sigue disponible
- **WHEN** `placementStrategy` es `free` y el usuario arrastra el reloj
- **THEN** la nueva posición se conserva y pasa a ser el origen del desplazamiento

### Requirement: El comportamiento es configurable y está desactivado por defecto

El desplazamiento SHALL exponerse mediante opciones en `Config.options`, con amplitud e intervalo ajustables. Los valores por defecto MUST dejar el comportamiento del shell idéntico al actual hasta que el usuario lo active.

#### Scenario: Instalación limpia sin cambio de comportamiento
- **WHEN** se carga la configuración sin que el usuario haya tocado las opciones nuevas
- **THEN** no se produce ningún desplazamiento y la interfaz se comporta como antes de la change

#### Scenario: Los ajustes se aplican en caliente
- **WHEN** se modifican la amplitud o el intervalo en la configuración con la sesión en marcha
- **THEN** el nuevo valor surte efecto sin reiniciar el shell

#### Scenario: Amplitud cero equivale a desactivado
- **WHEN** la amplitud se fija a cero
- **THEN** no se produce ningún movimiento y no se programa ningún temporizador
