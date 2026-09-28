## Why

The ii wallpaper selector only lists still-image extensions even though `scripts/colors/switchwall.sh` already supports animated wallpapers through `mpvpaper`. This splits wallpaper selection between the shell selector and the fallback file picker, and gives users no visual indication that a video wallpaper is available.

## What Changes

- Include supported animated wallpaper formats in `services/Wallpapers.qml` folder browsing.
- Generate and cache first-frame thumbnails for video entries using the existing thumbnail pipeline and `ffmpeg`.
- Show video thumbnails in `modules/ii/wallpaperSelector/WallpaperDirectoryItem.qml` with an animated-media indicator.
- Apply selected videos through the existing `Wallpapers.apply()` and `scripts/colors/switchwall.sh` path.
- Preserve the current `mpvpaper` playback, color-generation thumbnail, and monitor-restore behavior.
- Keep selector previews static; do not launch one video player per grid item.

## Capabilities

### New Capabilities

- `animated-wallpaper-selector`: Browse, preview, identify, and apply supported video wallpapers from the ii wallpaper selector.

### Modified Capabilities

<!-- No existing OpenSpec capabilities are present in openspec/specs/. -->

## Impact

- `services/Wallpapers.qml` — video extensions and thumbnail generation coordination.
- `modules/common/Images.qml` — video-format recognition.
- `modules/common/widgets/ThumbnailImage.qml` — video first-frame thumbnail support.
- `modules/ii/wallpaperSelector/WallpaperDirectoryItem.qml` — video preview and indicator.
- `scripts/thumbnails/generate-thumbnails-magick.sh` — fallback first-frame generation for videos.
- `scripts/colors/switchwall.sh` — existing playback path remains the source of truth.
- Requires the already-used `ffmpeg` and `mpvpaper` commands for animated wallpaper application.
