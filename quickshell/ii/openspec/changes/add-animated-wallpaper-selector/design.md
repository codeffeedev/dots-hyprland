## Context

The animated-wallpaper path already exists outside the selector. `scripts/colors/switchwall.sh` detects video extensions, checks `mpvpaper` and `ffmpeg`, starts one `mpvpaper` process per monitor, extracts a first frame into `~/.config/hypr/custom/scripts/mpvpaper_thumbnails`, and stores both `background.wallpaperPath` and `background.thumbnailPath`. `modules/ii/background/Background.qml` uses the stored thumbnail for sizing, colors, widget placement, and lock-screen blur while `mpvpaper` renders the live wallpaper below the shell.

The selector does not expose that path. `services/Wallpapers.qml` filters `FolderListModel` with still-image extensions only. `modules/ii/wallpaperSelector/WallpaperDirectoryItem.qml` only loads `ThumbnailImage` for `Images.isValidImageByName(...)`, and `scripts/thumbnails/generate-thumbnails-magick.sh` intentionally skips video files.

## Goals / Non-Goals

**Goals:**

- List supported video wallpaper files in the existing ii wallpaper selector.
- Show a cached static first-frame preview with a clear animated-media indicator.
- Reuse the existing `Wallpapers.select()` and `switchwall.sh` apply path.
- Keep the selector responsive and avoid starting video playback for preview tiles.
- Preserve current color generation, `thumbnailPath`, per-monitor playback, and generated restore-script behavior.
- Degrade gracefully when preview generation dependencies are unavailable.

**Non-Goals:**

- No new wallpaper playback service or replacement for `mpvpaper`.
- No live video playback inside selector tiles.
- No new settings section for pause, mute, battery, lock-screen, or performance policies.
- No changes to the frosted bar or screen-corner behavior.
- No change to still-image thumbnail behavior beyond shared format handling.

## Decisions

### Centralize video format recognition

Add video extensions and an `isValidVideoByName` helper to `modules/common/Images.qml`. Make `services/Wallpapers.qml` derive its folder filter from the same supported video list instead of maintaining a second list. This keeps selector discovery and delegate classification aligned.

Alternative rejected: hard-code video suffixes independently in `Wallpapers.qml` and `WallpaperDirectoryItem.qml`; that would allow files to be listed without a matching preview path.

### Use the existing Freedesktop thumbnail cache

Extend `scripts/thumbnails/generate-thumbnails-magick.sh` with an `ffmpeg` first-frame branch for supported video files. Store output using the same URI hash and size directory used by `ThumbnailImage.qml`. The selector continues to use `ThumbnailImage` with generation disabled, so visible entries load cached output without spawning a player.

The directory-generation command in `services/Wallpapers.qml` must run the image thumbnail generator and the video-capable fallback independently. A successful image thumbnail pass must not prevent video thumbnails from being generated.

Alternative rejected: generate a video frame from each QML delegate. That can create many concurrent `ffmpeg` processes while scrolling and makes UI load dependent on viewport behavior.

### Keep selection behavior unchanged

Selecting a video passes its source path through `Wallpapers.select()` and `Wallpapers.apply()`. `switchwall.sh` remains the source of truth for dependency checks, `mpvpaper` lifecycle, first-frame color generation, and restore-script generation.

Alternative rejected: launch `mpvpaper` directly from QML; that would duplicate shell-script behavior and bypass existing error notifications and config updates.

### Static preview with explicit video affordance

`WallpaperDirectoryItem.qml` loads the cached first frame for video files and overlays a small `movie` or equivalent Material icon. If no frame exists, it retains the existing non-preview fallback instead of showing a broken image.

## Risks / Trade-offs

- **Missing `ffmpeg` leaves video previews unavailable** -> Keep the file selectable through the existing apply path and show the fallback icon; `switchwall.sh` already reports missing dependencies when applying.
- **Video thumbnail generation is CPU and disk work** -> Generate only one first frame per cache size, skip existing cache files, and never start playback for selector previews.
- **Cache size selection differs before a thumbnail loads** -> Preserve the existing `ThumbnailImage` cache naming contract and verify normal, large, and x-large selector sizes against generated paths.
- **Video playback can cover multiple monitors** -> Do not alter `switchwall.sh`; verify selection still starts one process per active monitor and generated restore code remains intact.
- **A video path may remain selected after a failed apply** -> Rely on the existing dependency check ordering, which validates required commands before writing the wallpaper path.

## Migration Plan

1. Add video recognition and selector filtering without changing existing config keys.
2. Extend thumbnail generation and verify cached first frames for each supported video extension.
3. Add the video preview indicator and verify keyboard, mouse, search, and selected-item behavior.
4. Apply a video through the selector and verify `background.wallpaperPath`, `background.thumbnailPath`, `mpvpaper` processes, and restart restore behavior.
5. Roll back by removing video extensions from `Images.qml` and `Wallpapers.qml`; existing still-image selection and the fallback picker remain unaffected.

## Open Questions

- Should the selector indicator use `movie` or `play_circle` from the Material symbol set?
- Should animated files be listed alongside still images or grouped behind a filter in a later change?
