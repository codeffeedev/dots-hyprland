## 1. Video Format Discovery

- [x] 1.1 Add supported video extensions and `isValidVideoByName()` to `modules/common/Images.qml`, with case-insensitive matching.
- [x] 1.2 Update `services/Wallpapers.qml` to include the shared video extensions in `FolderListModel.nameFilters` without changing still-image filters.
- [x] 1.3 Update wallpaper directory classification so supported videos request the same cached thumbnail path used by `ThumbnailImage.qml`.

## 2. Thumbnail Generation

- [x] 2.1 Extend `scripts/thumbnails/generate-thumbnails-magick.sh` to extract one first frame from supported videos with `ffmpeg`, resize it to the requested cache size, and skip existing cache files.
- [x] 2.2 Make video thumbnail generation use the existing Freedesktop URI hash and `$HOME/.cache/thumbnails/<size>/` output layout.
- [x] 2.3 Update `Wallpapers.generateThumbnail()` so a successful still-image thumbnail pass cannot suppress the video-capable fallback pass.
- [x] 2.4 Verify missing `ffmpeg` leaves still-image generation functional and produces a non-fatal video preview failure.

## 3. Selector Presentation

- [x] 3.1 Render cached first-frame thumbnails for video entries in `modules/ii/wallpaperSelector/WallpaperDirectoryItem.qml` without starting playback.
- [x] 3.2 Add a small animated-media indicator to video tiles while preserving filename, hover, focus, and selected-item styling.
- [ ] 3.3 Verify mouse activation, keyboard activation, grid navigation, search filtering, and current-wallpaper highlighting for video entries.

## 4. Existing Apply Path

- [ ] 4.1 Apply one video through the ii selector and verify it still uses `Wallpapers.select()` and `scripts/colors/switchwall.sh`.
- [ ] 4.2 Verify successful video selection updates `background.wallpaperPath` and `background.thumbnailPath`, starts one `mpvpaper` process per active monitor, and preserves shell color generation.
- [ ] 4.3 Verify missing `mpvpaper` or `ffmpeg` reports the existing switchwall error and does not leave an unapplied video path configured.
- [ ] 4.4 Verify the generated `/home/as/.config/hypr/custom/scripts/__restore_video_wallpaper.sh` restores the selected video after the Hyprland startup path in `hyprland/execs.lua`.

## 5. Regression Verification

- [ ] 5.1 Run `qmlformat` on changed QML files and validate shell startup/reload with the ii family active.
- [ ] 5.2 Verify still-image selection, thumbnail generation, fallback picker behavior, and wallpaper color generation remain unchanged.
- [ ] 5.3 Verify selector scrolling does not launch long-running playback processes for preview tiles and repeated thumbnail generation reuses cache files.
