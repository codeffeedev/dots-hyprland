## ADDED Requirements

### Requirement: La referencia upstream se conserva como solo lectura

El repositorio SHALL conservar la referencia `origin/main` de `codeffeedev/dots-hyprland` como material de consulta. Las ramas `master` y `origin/main` MUST tratarse como historiales sin ancestro común: no se ejecutan `git merge`, `git rebase` ni `git pull` entre ambas.

#### Scenario: La referencia sigue disponible
- **WHEN** se ejecuta `git rev-parse origin/main` desde `~/.config` tras aplicar la change
- **THEN** el comando resuelve a un commit válido

#### Scenario: Las ramas no comparten ancestro
- **WHEN** se ejecuta `git merge-base master origin/main` desde `~/.config`
- **THEN** el comando falla o no devuelve ningún commit, confirmando que master es huérfana

### Requirement: La diferencia de rutas está documentada y no se resuelve por merge

El árbol de ii vive en `quickshell/ii/` en la rama local y en `dots/.config/quickshell/ii/` en upstream. Esta asimetría SHALL estar documentada en el repositorio. El procedimiento de comparación MUST operar sobre el prefijo de ruta correspondiente en cada lado.

#### Scenario: La asimetría está documentada
- **WHEN** se lee la documentación del repositorio
- **THEN** indica que `quickshell/ii/<ruta>` en local corresponde a `dots/.config/quickshell/ii/<ruta>` en `origin/main`, y que por ello las operaciones de merge no son aplicables

#### Scenario: La comparación de un fichero funciona
- **WHEN** se compara un fichero presente en ambos lados, por ejemplo `modules/ii/bar/Bar.qml`, usando el prefijo correcto en cada uno
- **THEN** se obtiene un diff legible sin errores de ruta inexistente

### Requirement: La divergencia frente a upstream es consultable

El repositorio SHALL ofrecer un medio versionado y repetible para listar qué ficheros del árbol local no existen en upstream, cuáles existen solo en upstream y cuáles difieren en contenido.

#### Scenario: Se listan los ficheros exclusivamente locales
- **WHEN** se ejecuta el procedimiento de comparación
- **THEN** identifica como exclusivos del árbol local, entre otros, `modules/ii/bitwardenUnlock/BitwardenUnlock.qml`, `modules/settings/ScreenConfig.qml`, el directorio `openspec/` y el directorio `.opencode/`

#### Scenario: Se listan los ficheros ausentes en local
- **WHEN** se ejecuta el procedimiento de comparación
- **THEN** identifica como presentes solo en upstream los iconos ausentes bajo `assets/icons/`, y señala `modules/common/widgets/shapes` como diferencia esperada por la vendorización

#### Scenario: El resultado distingue divergencia intencionada de deriva
- **WHEN** se consulta el resultado de la comparación
- **THEN** la documentación acompaña el listado indicando qué rutas son personalizaciones deliberadas y cuáles requieren revisión
