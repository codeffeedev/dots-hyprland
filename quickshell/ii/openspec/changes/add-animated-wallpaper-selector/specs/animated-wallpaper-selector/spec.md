## ADDED Requirements

### Requirement: Video wallpapers are discoverable

The ii wallpaper selector SHALL list supported video wallpaper files with the existing still-image entries. Supported video extensions SHALL include `mp4`, `webm`, `mkv`, `avi`, and `mov`, case-insensitively.

#### Scenario: Mixed wallpaper directory

- **WHEN** the selected directory contains supported images, supported videos, and unsupported files
- **THEN** the selector shows the supported images and videos and excludes unsupported files

#### Scenario: Uppercase video extension

- **WHEN** a readable file has an uppercase supported video extension
- **THEN** the selector treats it as an animated wallpaper

### Requirement: Video entries have static previews

The selector SHALL display a cached first-frame thumbnail for a supported video when that thumbnail exists. The selector MUST NOT start video playback for a preview tile.

#### Scenario: Cached first frame exists

- **WHEN** a video entry has a valid cached first-frame thumbnail
- **THEN** the selector displays that thumbnail using the existing wallpaper tile sizing and masking

#### Scenario: First frame is missing

- **WHEN** a video entry has no cached first-frame thumbnail and thumbnail generation cannot produce one
- **THEN** the selector keeps the entry selectable and displays its non-preview fallback without a broken-image state

#### Scenario: Video tile enters the viewport

- **WHEN** a video tile is created or becomes visible in the grid
- **THEN** the selector does not launch `mpvpaper` or another long-running playback process for that tile

### Requirement: Animated entries are identifiable

The selector SHALL provide a visible animated-media indicator on video entries without obscuring the filename or replacing keyboard selection feedback.

#### Scenario: Video entry is rendered

- **WHEN** a supported video is rendered in the wallpaper grid
- **THEN** the tile displays an animated-media indicator and still responds to hover, focus, and selected-item styling

### Requirement: Video thumbnails use the shared cache

Video first-frame thumbnails SHALL use the existing Freedesktop-style thumbnail cache naming and size directories used by `ThumbnailImage.qml`. Thumbnail generation SHALL skip an output that already exists for the same source URI and size.

#### Scenario: Thumbnail generation runs twice

- **WHEN** the selector requests thumbnails for a directory that was already processed at the same size
- **THEN** existing video thumbnails are reused and no second `ffmpeg` extraction is required for those files

#### Scenario: Thumbnail generation runs without ffmpeg

- **WHEN** the selector requests video thumbnails and `ffmpeg` is unavailable
- **THEN** thumbnail generation reports the unavailable preview without preventing still-image thumbnail generation or video selection

### Requirement: Video selection uses existing playback

Selecting a video in the ii wallpaper selector SHALL use the existing `Wallpapers.select()` and `scripts/colors/switchwall.sh` path. The selector SHALL NOT implement a second playback or configuration-writing path.

#### Scenario: User selects a video

- **WHEN** the user activates a supported video entry with the mouse or keyboard
- **THEN** the existing wallpaper switch path receives the source video path
- **AND** `background.wallpaperPath` is set to that source path
- **AND** the existing playback path starts the animated wallpaper for each active monitor

#### Scenario: Video color frame is generated

- **WHEN** the existing wallpaper switch path successfully applies a video
- **THEN** it stores a usable first-frame path in `background.thumbnailPath` for shell sizing, color generation, and background behavior

#### Scenario: Apply dependencies are missing

- **WHEN** the selected video cannot be applied because an existing required dependency is unavailable
- **THEN** the existing switch path reports the failure and does not replace the configured wallpaper path with an unapplied video

### Requirement: Existing still wallpaper behavior remains stable

Adding video support SHALL NOT change still-image selection, thumbnail generation, keyboard navigation, current-item indication, or fallback file-picker behavior.

#### Scenario: Still image remains selected

- **WHEN** the user selects a supported still image
- **THEN** the existing still-image apply and color-generation behavior remains unchanged

#### Scenario: Fallback picker is used

- **WHEN** the user chooses the system file dialog instead of the ii selector
- **THEN** the existing fallback picker continues to accept the same wallpaper paths, including its current video behavior
