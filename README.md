# oTune

oTune is a Windows music player for local files, full tracks from Audius and Wikimedia Commons, and audio links. It has a floating widget with its own video or photo background.

## Install

Download the Windows x64 installer from [Releases](https://github.com/ararat-hub/OfflineTunes/releases). YouTube playback uses Microsoft Edge WebView2 Runtime.

- Use **Add** to scan a music folder or play an audio or YouTube link.
- **Search** finds music in your library, public streams on Audius, and openly licensed recordings on Wikimedia Commons. Online results link to their sources.
- **Library** includes a recently played list. **Discover** shows popular Audius tracks ranked by play count, tracks you play most often, and suggestions from your library.
- **Downloads** previews a section planned for the mobile version.
- Use **Settings → Appearance** to import video, photos, and TTF or OTF fonts. Choose a saved background and video loop range separately for the player and floating widget.
- Use **Settings → Sound** to set the equalizer for audio tracks.
- Use **Settings → Language** to select Russian, English, Spanish, German, or French.
- Use **Settings → Shortcuts** to enable and change global Windows shortcuts for playback, volume, and the floating widget.
- **Settings → Updates** checks for newer GitHub releases and lets you turn automatic prompts on or off.

YouTube links play in the official embedded player when available. If YouTube returns error 101 or 150, oTune opens the video's standard YouTube watch page inside the app. On that page use the YouTube playback controls. Access still depends on YouTube's availability, account requirements, and regional restrictions.

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
