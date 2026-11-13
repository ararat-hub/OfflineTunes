# oTune

oTune is a music player for Windows and Android with local files, full tracks from online catalogs, and audio links. The compact player has its own video or photo background and can save named configurations.

## Install

Download the Windows x64 installer or the Android APK from [Releases](https://github.com/ararat-hub/OfflineTunes/releases). On Windows, embedded YouTube playback uses Microsoft Edge WebView2 Runtime. Android opens YouTube links in the YouTube app or browser.

- Use **Add** to scan a music folder on Windows, import audio files on Android, or open a link.
- **Search** has All tracks, Library, and Favorites filters. The online sources and licensing information are available in the track details.
- **Library** includes a recently played list. **Discover** shows popular Audius tracks ranked by play count, tracks you play most often, and suggestions from your library.
- On Android, tap the download icon on an eligible track. Open **Library → Downloads** to play or remove offline copies. Available downloads include openly licensed Wikimedia Commons recordings and Audius tracks whose creators have enabled public downloads.
- Use **Settings → Appearance** to import video, photos, and TTF or OTF fonts. Choose a saved background and video loop range separately for the player and widget. Save widget configurations and reuse the videos or photos already imported. The Android widget opens inside oTune.
- **Settings → Date and time** controls the time zone used for the clock, date, and weekday.
- Use **Settings → Sound** to set the equalizer for audio tracks.
- Use **Settings → Language** to select Russian, English, Spanish, German, or French.
- Use **Settings → Shortcuts** to enable and change global Windows shortcuts for playback, volume, and the floating widget.
- **Settings → Updates** checks for newer GitHub releases and lets you turn automatic prompts on or off.

On Windows, YouTube links play in the official embedded player when available. If YouTube returns error 101 or 150, oTune opens the video's standard YouTube watch page inside the app. Use the YouTube playback controls on that page.

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

## Build for Android

Install Flutter and the Android SDK, then run `flutter pub get` and `flutter build apk --release`. To sign the release, provide `OTUNE_ANDROID_KEYSTORE` and `OTUNE_ANDROID_STORE_PASSWORD` in your build environment and use the key alias `otune`.

The [design spec](docs/design-spec.md) describes the original project plan.
