# Study Tracker

Study Tracker is a native macOS SwiftUI app for turning a folder of course files into a completion tracker. It scans nested folders, groups files into sections, tracks completion, supports project todos, and can create Markdown notes that open in your preferred editor.

## Features

- Open a Finder folder as a study project.
- Recursive scanning for videos, audio, PDFs, Markdown, code, slides, documents, spreadsheets, images, archives, and other files.
- File metadata including video/audio duration, PDF page count, text word count, file size, and last opened date.
- Screenshot-style progress dashboard with overall and section progress.
- Smart views for all files, in-progress, completed, unstarted, and favorites.
- Sorting, grouping, searching, and file-type filtering.
- Manual projects, lists, and items in addition to folder-backed projects.
- Project todo list with complete/reopen/remove actions.
- Batch selection with complete, incomplete, favorite, unfavorite, and remove actions.
- Markdown note creation with editor preference for System Default, VS Code, or Zed.
- JSON/CSV progress export.
- Local release DMG packaging with an app icon.

## Requirements

- macOS 14 or newer
- Xcode command line tools or Xcode with Swift 6 support

## Run Locally

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

## Build The DMG

```bash
./script/build_dmg.sh
```

The generated disk image is written to:

```text
dist/Study Tracker-0.1.dmg
```

The DMG build script:

- builds the app in release mode,
- stages a proper `.app` bundle,
- includes `Resources/AppIcon.icns`,
- applies ad-hoc signing for local validation,
- creates a compressed DMG with an Applications shortcut,
- verifies the DMG checksum.

## Distribution Notes

The default DMG is suitable for local sharing/testing. For public distribution, sign with a Developer ID certificate and notarize with Apple.

## Data Storage

The app stores progress metadata locally in Application Support. It does not copy or modify source files, except when you explicitly create a new Markdown file.

## Repository Layout

```text
Package.swift
Sources/StudyTracker/
Resources/AppIcon.icns
script/build_and_run.sh
script/build_dmg.sh
script/generate_app_icon.swift
.codex/environments/environment.toml
```

## License

No license has been specified yet.
