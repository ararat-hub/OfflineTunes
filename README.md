# OfflineTunes

OfflineTunes is a Windows music player for local files and audio links. It has a customizable floating widget and supports looping video backgrounds in the player and widget.

## Install

Download the Windows x64 installer from [Releases](https://github.com/ararat-hub/OfflineTunes/releases). YouTube playback uses Microsoft Edge WebView2 Runtime.

- Use **Add** to scan a music folder or play an audio or YouTube link.
- Use **Settings → Appearance** to pick a preset, import your own video, or customize the floating widget. Imported videos stay on your PC at their original quality.
- Use **Settings → Language** to select Russian, English, or Spanish.
- Use **Settings → Shortcuts** to enable and change global Windows shortcuts for playback, volume, and the floating widget.

YouTube links play in the official embedded player when available. If YouTube returns error 101 or 150, OfflineTunes opens the video's standard YouTube watch page inside the app. On that page use the YouTube playback controls. Access still depends on YouTube's availability, account requirements, and regional restrictions.

## Build for Windows

Install Flutter, Visual Studio with the Desktop development with C++ workload, Python 3, and NSIS. Use a Flutter SDK path without non-ASCII characters if its shader compiler cannot read the SDK path.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
python installer/build_installer.py --makensis C:/path/to/makensis.exe --vc-runtime C:/path/to/x64/Microsoft.VC143.CRT --output dist
```

The installer version comes from `pubspec.yaml`. The `--vc-runtime` argument takes the x64 Visual C++ redistributable directory under Visual Studio's `VC/Redist/MSVC` directory.

The [design spec](docs/design-spec.md) describes the original project plan.
