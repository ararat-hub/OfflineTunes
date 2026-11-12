# Карта проекта: «OfflineTunes» — офлайн-плеер с онлайн-загрузкой, плейлистами и импортом с устройства

**Версия ТЗ: 1.2** · Платформы: Android (APK/AAB) + Windows (.exe) · Одна кодовая база

> Этот документ — техническое задание для ИИ-кодера (Gemini / Claude / Cursor).
> Требование к исполнителю: **не менять стек и структуру папок**, реализовывать файлы строго по списку, после каждого этапа запускать проверки из раздела 15.
> Новое в версии 1.1: полноценные плейлисты (раздел 7), импорт музыки с устройства (раздел 8), система визуала и смены фона (раздел 9).
> Новое в версии 1.2: дизайн-токены (9.6), покомпонентный дизайн главного экрана (9.7), экрана плеера (9.8) и mini-player (9.9).

---

## 1. Что делаем

Музыкальный плеер, у которого есть три источника музыки и одна общая библиотека:

1. **Онлайн-каталог** — поиск и стриминг из легального API.
2. **Скачанное** — любой трек из каталога загружается «внутрь» приложения и играется **полностью офлайн**.
3. **Локальные файлы пользователя** — импорт mp3/flac/m4a/ogg/wav с устройства (файлы, папки, или скан медиатеки Android) с чтением ID3-тегов и встроенных обложек.

Плюс: плейлисты (обычные и смарт), очередь воспроизведения, современный «нешумный» интерфейс с настраиваемым фоном и темой.

### Ключевые пользовательские сценарии
1. Открыть приложение → подборки → Play → трек играет стримом.
2. «Скачать» → прогресс → трек в разделе «Моя музыка», доступен офлайн.
3. Отключить интернет → библиотека, плейлисты, плеер, обложки работают.
4. **Импорт:** «Добавить свою музыку» → выбрать файлы или папку → теги и обложки прочитаны → треки в библиотеке рядом со скачанными.
5. **Плейлисты:** создать, переименовать, поставить свою обложку, перетащить порядок треков, скачать плейлист целиком одной кнопкой.
6. **Смарт-плейлисты:** «Недавно добавленные», «Часто слушаю», «Забытые», «По жанру» — обновляются сами.
7. **Очередь:** «Играть следующим», «В конец очереди», просмотр и перетасовка очереди, восстановление после перезапуска.
8. **Визуал:** сменить тему (тёмная/светлая/системная/AMOLED), включить «цвет из обложки», поставить своё фото как фон приложения с настройкой размытия и затемнения.
9. Свернуть приложение (Android) → музыка играет, управление в уведомлении и на экране блокировки.

---

## 2. Стек (обязательный)

| Слой | Технология | Версия | Почему |
|---|---|---|---|
| Фреймворк | Flutter (Dart), stable | ≥ 3.35 | Android + Windows из одной кодовой базы, реальная сборка .exe |
| Аудио | just_audio | ^0.10.6 | стрим по URL, локальные файлы, gapless, seek, скорость |
| Фон/уведомление | just_audio_background + audio_service | ^0.0.1-beta.17 / ^0.18.19 | MediaSession, экран блокировки |
| БД | drift (SQLite) | ^2.34.4 | реактивные запросы, миграции, обе платформы |
| Сеть | dio | ^5.11.1 | download с прогрессом, resume, отмена |
| State | flutter_riverpod | ^3.4.3 | провайдеры, тестируемость |
| **Выбор файлов/папок** | file_picker | ^12.2.0 | Android + Windows, выбор файлов и директорий |
| **Чтение тегов** | audio_metadata_reader | ^1.4.2 | ID3 / Vorbis / iTunes-теги + встроенная обложка, чистый Dart → работает и на Windows |
| **Медиатека Android** | on_audio_query | ^2.9.0 | скан MediaStore. **Только Android**, вызывать под `if (Platform.isAndroid)` |
| Разрешения | permission_handler | ^13.0.2 | READ_MEDIA_AUDIO, POST_NOTIFICATIONS |
| Выбор фонового фото | image_picker | ^1.2.3 | Android 24+, Windows 10+ |
| Настройки | shared_preferences | ^2.5.5 | тема, фон, качество, лимиты |
| Шрифты | google_fonts | ^8.2.1 | Inter / Manrope |
| Анимации | flutter_animate | ^4.5.2 | микроанимации без бойлерплейта |
| Цвет из обложки | **material_color_utilities** (входит в Flutter SDK) | — | `palette_generator` **discontinued**, использовать нельзя |
| Установщик Windows | Inno Setup | — | папка сборки → один .exe-установщик |

### pubspec.yaml

```yaml
name: offlinetunes
description: Offline-first music player
publish_to: 'none'
version: 1.1.0+1

environment:
  sdk: '>=3.6.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  # аудио
  just_audio: ^0.10.6
  just_audio_background: ^0.0.1-beta.17
  audio_service: ^0.18.19
  # состояние и сеть
  flutter_riverpod: ^3.4.3
  dio: ^5.11.1
  # БД
  drift: ^2.34.4
  sqlite3_flutter_libs: ^0.5.0
  # файлы, импорт, теги
  path_provider: ^2.1.0
  path: ^1.9.0
  file_picker: ^12.2.0
  audio_metadata_reader: ^1.4.2
  on_audio_query: ^2.9.0          # только Android
  permission_handler: ^13.0.2
  # UI / визуал
  cached_network_image: ^3.4.0
  google_fonts: ^8.2.1
  flutter_animate: ^4.5.2
  image_picker: ^1.2.3
  shared_preferences: ^2.5.5
  material_color_utilities: any   # версия должна совпасть с той, что тянет Flutter SDK
  # утилиты
  crypto: ^3.0.0
  connectivity_plus: ^6.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  drift_dev: ^2.34.0
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/backgrounds/
```

> `material_color_utilities` жёстко пинить нельзя — Flutter SDK сам задаёт версию. Если pub ругается на конфликт, ставить `any`.
> Остальные версии — минимумы; поднимать патчи можно, понижать мажоры нельзя. Пакеты, которых нет в этом списке, **не добавлять** без явного согласования.

---

## 3. Источник треков (легальный, без ключей-заглушек)

### 3.1 Основной: Jamendo API v3.0
Каталог Creative Commons, официально разрешает и стрим, и **скачивание** — это критично для офлайн-режима.

- Base URL: `https://api.jamendo.com/v3.0/`
- Обязательный параметр `client_id` (бесплатно на devportal.jamendo.com), `format=json`
- Лента/поиск: `GET /v3.0/tracks/?client_id=KEY&format=json&limit=50&offset=0&search=QUERY&include=musicinfo+stats&audioformat=mp32&audiodlformat=mp32`
- Нужные поля: `id`, `name`, `artist_name`, `album_name`, `duration`, `image`, `audio` (стрим), `audiodownload` (загрузка), `audiodownload_allowed` (bool), `license_ccurl`, `musicinfo.tags.genres`
- **Правило:** `audiodownload_allowed == false` → кнопка «Скачать» неактивна, подсказка «Правообладатель запретил загрузку».
- Документация: https://developer.jamendo.com/v3.0/tracks

### 3.2 Дополнительный (опционально, за интерфейсом): Audius REST API
Host discovery через `https://api.audius.co` → выбрать host → `GET {host}/v1/tracks/search?query=...&app_name=OfflineTunes`, стрим `GET {host}/v1/tracks/{id}/stream`. Точные пути сверять по https://docs.audius.co/developers/api/search-tracks/ перед реализацией.

### 3.3 Архитектурное требование
Источник спрятан за абстракцией `MusicSource` (см. 6.2). Новый каталог = новый класс, **без правок UI и БД**.

### 3.4 Юридическая рамка (не нарушать)
Запрещено реализовывать загрузку из YouTube, Spotify, VK, Yandex Music, SoundCloud и любых сервисов, чьи ToS это запрещают. Только каталоги, явно разрешающие загрузку (Jamendo CC, Free Music Archive, Audius), плюс **личные файлы пользователя** (раздел 8). На экране трека выводить автора и лицензию (`license_ccurl`).

---

## 4. Архитектура

```
UI (Flutter widgets)
   ↓
Riverpod providers
   playerProvider · queueProvider · libraryProvider · playlistsProvider
   downloadQueueProvider · searchProvider · importProvider · themeProvider
   ↓
Repositories
   TrackRepository · PlaylistRepository · SettingsRepository
   ↓                    ↓                      ↓
MusicSource (сеть)  AppDatabase (drift)   FileStorage (файлы)
                                          LocalImportService (импорт с устройства)
   ↓
AudioEngine → PlaybackService (just_audio + just_audio_background)
```

Принцип **offline-first**: UI не обращается к сети напрямую. Плеер получает `Uri` от `TrackRepository.resolvePlayableUri(track)`:

- `origin == local` → `Uri.file(localPath)` (файл пользователя, всегда офлайн);
- `origin == remote` и есть валидный `localPath` → `Uri.file(...)`;
- `origin == remote`, файла нет, сеть есть → `Uri.parse(streamUrl)`;
- иначе → `TrackUnavailableException`, UI показывает «Трек недоступен офлайн».

---

## 5. Структура файлов (создавать ровно так)

```
offlinetunes/
├─ pubspec.yaml
├─ analysis_options.yaml
├─ assets/images/placeholder_cover.png
├─ assets/backgrounds/       # 4–6 встроенных градиентных фонов (webp, ≤200 КБ каждый)
├─ lib/
│  ├─ main.dart                       # JustAudioBackground.init, ProviderScope, restore state
│  ├─ app.dart                        # MaterialApp, темы, адаптивная навигация
│  ├─ core/
│  │  ├─ constants.dart
│  │  ├─ strings.dart                 # ВСЕ русские строки UI
│  │  ├─ result.dart
│  │  ├─ failures.dart
│  │  └─ connectivity.dart
│  ├─ theme/                                    # ← НОВОЕ (разделы 9.1–9.10)
│  │  ├─ tokens.dart                   # ВСЕ отступы, цвета, радиусы, длительности (9.6)
│  │  ├─ app_theme.dart                # ThemeData light/dark/amoled, Material 3
│  │  ├─ theme_controller.dart         # Riverpod: режим, акцент, шрифт, фон
│  │  ├─ theme_settings.dart           # модель настроек визуала + toJson/fromJson
│  │  ├─ cover_color_extractor.dart    # material_color_utilities: seed-цвет из обложки
│  │  └─ background_painter.dart       # рендер фона: градиент / встроенный / фото
│  ├─ data/
│  │  ├─ db/
│  │  │  ├─ database.dart
│  │  │  ├─ tables.dart
│  │  │  └─ database.g.dart            # build_runner
│  │  ├─ source/
│  │  │  ├─ music_source.dart
│  │  │  ├─ jamendo_source.dart
│  │  │  └─ dto/jamendo_track_dto.dart
│  │  ├─ storage/
│  │  │  ├─ file_storage.dart
│  │  │  └─ download_manager.dart
│  │  ├─ import/                                # ← НОВОЕ (раздел 8)
│  │  │  ├─ local_import_service.dart  # выбор файлов/папок, обход, дедуп, запись в БД
│  │  │  ├─ metadata_reader.dart       # audio_metadata_reader → теги + обложка
│  │  │  ├─ folder_watcher.dart        # «следить за папкой», пересканирование
│  │  │  └─ media_store_scanner.dart   # on_audio_query, ТОЛЬКО Android
│  │  └─ repository/
│  │     ├─ track_repository.dart
│  │     ├─ playlist_repository.dart   # + смарт-плейлисты, M3U (раздел 7)
│  │     └─ settings_repository.dart
│  ├─ domain/
│  │  ├─ track.dart                    # + origin, genre, year, trackNo
│  │  ├─ playlist.dart                 # + isSmart, smartRule, coverPath
│  │  ├─ smart_rule.dart               # правила смарт-плейлистов
│  │  └─ download_task.dart
│  ├─ player/
│  │  ├─ audio_engine.dart             # интерфейс (см. 6.3)
│  │  ├─ just_audio_engine.dart
│  │  ├─ playback_service.dart         # queue, shuffle, repeat, seek, sleep-timer
│  │  ├─ queue_controller.dart         # «играть следующим», reorder, persist
│  │  └─ player_providers.dart
│  ├─ features/
│  │  ├─ home/
│  │  │  ├─ home_screen.dart           # CustomScrollView + slivers (9.7)
│  │  │  └─ sections/                  # continue_card · quick_tiles · section_carousel
│  │  │                                #  playlists_row · smart_row · catalog_row
│  │  │                                #  recent_list · offline_banner · onboarding_card
│  │  ├─ search/search_screen.dart
│  │  ├─ library/
│  │  │  ├─ library_screen.dart        # табы: Треки · Артисты · Альбомы · Свои файлы
│  │  │  └─ library_filters.dart
│  │  ├─ playlists/
│  │  │  ├─ playlists_screen.dart      # сетка плейлистов + смарт-плейлисты
│  │  │  ├─ playlist_detail_screen.dart# reorder, множественный выбор
│  │  │  ├─ create_playlist_sheet.dart
│  │  │  └─ add_to_playlist_sheet.dart
│  │  ├─ import/import_screen.dart     # мастер импорта + лог результата
│  │  ├─ downloads/downloads_screen.dart
│  │  ├─ queue/queue_screen.dart
│  │  ├─ player/
│  │  │  ├─ now_playing_screen.dart    # 9.8
│  │  │  ├─ progress_bar.dart          # кастомный слайдер + tabular figures
│  │  │  ├─ player_controls.dart       # 5 основных кнопок
│  │  │  ├─ extra_actions_row.dart     # скорость, таймер, очередь, лицензия
│  │  │  ├─ up_next_peek.dart          # «Далее в очереди»
│  │  │  └─ desktop_player_layout.dart # двухколоночная раскладка + горячие клавиши
│  │  └─ settings/
│  │     ├─ settings_screen.dart
│  │     └─ appearance_screen.dart     # тема, акцент, фон, размытие, затемнение
│  └─ widgets/
│     ├─ app_background.dart           # обёртка-фон для всех экранов
│     ├─ glass_surface.dart            # полупрозрачная карточка (BackdropFilter)
│     ├─ track_tile.dart               # общий тайл трека (9.7)
│     ├─ marquee_text.dart             # бегущая строка на AnimationController
│     ├─ playing_equalizer.dart        # 3 полоски у играющего трека
│     ├─ playlist_card.dart
│     ├─ mini_player.dart
│     ├─ download_button.dart
│     ├─ empty_state.dart
│     └─ skeleton.dart
├─ android/  · windows/
├─ installer/windows_installer.iss
└─ test/
   ├─ track_repository_test.dart
   ├─ playlist_repository_test.dart
   ├─ smart_rule_test.dart
   ├─ metadata_reader_test.dart
   ├─ m3u_test.dart
   ├─ download_manager_test.dart
   └─ db_migration_test.dart
```

---

## 6. Модели данных и контракты

### 6.1 Схема БД (drift), `schemaVersion = 2`

```dart
enum TrackOrigin { remote, local }   // remote = из каталога, local = файл пользователя

class Tracks extends Table {
  TextColumn get id => text()();                       // "jamendo:1848357" | "local:<sha1(path)>"
  IntColumn  get origin => intEnum<TrackOrigin>()();
  TextColumn get sourceId => text()();                 // "jamendo" | "device"
  TextColumn get remoteId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn  get year => integer().nullable()();
  IntColumn  get trackNo => integer().nullable()();
  IntColumn  get durationMs => integer()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get coverLocalPath => text().nullable()();
  TextColumn get streamUrl => text().nullable()();
  TextColumn get downloadUrl => text().nullable()();
  BoolColumn get downloadAllowed => boolean().withDefault(const Constant(true))();
  TextColumn get localPath => text().nullable()();     // null => нет файла
  TextColumn get sourcePath => text().nullable()();     // исходный путь при импорте «по ссылке»
  BoolColumn get isCopied => boolean().withDefault(const Constant(false))();  // скопирован внутрь
  IntColumn  get fileSizeBytes => integer().nullable()();
  TextColumn get fileHash => text().nullable()();      // sha1(size + первые 64 КБ) — дедуп
  TextColumn get licenseUrl => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isMissing => boolean().withDefault(const Constant(false))();
  IntColumn  get addedAt => integer()();
  IntColumn  get lastPlayedAt => integer().nullable()();
  IntColumn  get playCount => integer().withDefault(const Constant(0))();
  IntColumn  get skipCount => integer().withDefault(const Constant(0))();
  @override Set<Column> get primaryKey => {id};
}

class Playlists extends Table {
  IntColumn  get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();     // null => мозаика из 4 обложек
  BoolColumn get isSmart => boolean().withDefault(const Constant(false))();
  TextColumn get smartRuleJson => text().nullable()(); // только для isSmart
  IntColumn  get sortIndex => integer().withDefault(const Constant(0))();
  IntColumn  get createdAt => integer()();
  IntColumn  get updatedAt => integer()();
}

class PlaylistItems extends Table {
  IntColumn  get playlistId => integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId => text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn  get position => integer()();
  IntColumn  get addedAt => integer()();
  @override Set<Column> get primaryKey => {playlistId, trackId};
}

class Downloads extends Table {
  TextColumn get trackId => text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn  get state => integer()();     // 0 queued,1 running,2 done,3 failed,4 paused
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn  get receivedBytes => integer().withDefault(const Constant(0))();
  IntColumn  get totalBytes => integer().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn  get updatedAt => integer()();
  @override Set<Column> get primaryKey => {trackId};
}

class QueueItems extends Table {                       // очередь переживает перезапуск
  IntColumn  get position => integer()();
  TextColumn get trackId => text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  @override Set<Column> get primaryKey => {position};
}

class WatchedFolders extends Table {                   // «следить за папкой»
  IntColumn  get id => integer().autoIncrement()();
  TextColumn get path => text()();
  IntColumn  get lastScanAt => integer()();
}
```

Индексы (обязательно): `Tracks(origin)`, `Tracks(artist)`, `Tracks(album)`, `Tracks(addedAt)`, `Tracks(fileHash)`, `PlaylistItems(playlistId, position)`.

Миграция 1→2: добавить новые колонки через `m.addColumn`, создать таблицы `QueueItems` и `WatchedFolders`, существующим трекам проставить `origin = remote`. Обязателен тест миграции.

### 6.2 Контракт источника

```dart
abstract class MusicSource {
  String get id;
  Future<List<Track>> search(String query, {int limit = 50, int offset = 0});
  Future<List<Track>> featured({int limit = 50, int offset = 0});
  Future<Track> byId(String remoteId);
  Uri streamUri(Track t);
  Uri? downloadUri(Track t);   // null => скачивание запрещено
}
```

### 6.3 Абстракция плеера (страховка от несовместимости)

Интерфейс `AudioEngine`: `setUrl/setFile/play/pause/seek/setSpeed/dispose` + стримы `position`, `duration`, `state`. Реализация по умолчанию — `JustAudioEngine`. Если на Windows возникнут проблемы с `just_audio_windows`, добавляется `MediaKitEngine` (`media_kit ^1.2.6` + `media_kit_libs_windows_audio`) и подменяется провайдером по `Platform.isWindows`. **UI при этом не переписывается.**

### 6.4 Хранилище файлов

- Директории: `getApplicationSupportDirectory()` → `media/audio/`, `media/covers/`, `media/imported/`, `media/backgrounds/`
  - Android: `/data/data/<пакет>/files/...` (приватно, разрешения на storage не нужны)
  - Windows: `%APPDATA%\<company>\offlinetunes\media\...`
- Имена: `<sha1(trackId)>.<ext>`, обложка `<sha1(trackId)>.jpg`
- Загрузка в `<имя>.part` → атомарный `rename`. При старте все `.part` удаляются, задачи → `queued`.
- Целостность: `File.length()` vs `totalBytes`; расхождение → файл битый, `localPath = null`.

### 6.5 Менеджер загрузок

Максимум 3 параллельных; `dio.download` с `onReceiveProgress` (throttle 250 мс); resume через `Range: bytes=<receivedBytes>-` (если ответ 200 вместо 206 — с нуля); 3 ретрая с backoff 2/4/8 с; обложка качается сразу после аудио; отмена через `CancelToken` + удаление `.part`.

---

## 7. Плейлисты (полная спецификация)

### 7.1 Обычные плейлисты

| Операция | Требования |
|---|---|
| Создать | имя (1–100 символов, обязательное), описание (опц.), сразу можно добавить выбранные треки |
| Переименовать / описание | инлайн-редактирование, `updatedAt` обновляется |
| Обложка | своё изображение через `image_picker` → копируется в `media/covers/pl_<id>.jpg`; если не задана — мозаика 2×2 из обложек первых 4 треков |
| Добавить треки | `add_to_playlist_sheet` из карточки трека, из множественного выбора, из «Сейчас играет»; дубликаты не добавляются (сообщение «Уже в плейлисте») |
| Удалить трек | свайп влево + Undo в SnackBar (5 секунд) |
| Порядок | `ReorderableListView`, drag-handle справа; после перетаскивания `position` пересчитывается пачкой в одной транзакции |
| Сортировки (не меняя порядок) | по названию / артисту / длительности / дате добавления — как режим отображения, хранится в prefs на плейлист |
| Удалить плейлист | подтверждение; треки и файлы **не** удаляются (только связи, каскадом) |
| Дублировать | «Копия — <имя>» с тем же составом |
| Порядок плейлистов | drag-n-drop в сетке, хранится в `sortIndex` |
| Play / Shuffle | кнопки в шапке: заменить очередь плейлистом целиком, либо перемешать |
| **Скачать плейлист** | одна кнопка: все `origin == remote && localPath == null && downloadAllowed` → в очередь загрузок; индикатор «12 из 30 доступно офлайн» |
| Офлайн-фильтр | тумблер «Только офлайн» в шапке плейлиста |

### 7.2 Смарт-плейлисты (генерируются запросом, не хранят состав)

Модель правила (сериализуется в `smartRuleJson`):

```dart
class SmartRule {
  final List<SmartCondition> conditions;   // AND между условиями
  final SmartSort sort;                    // поле + направление
  final int? limit;
}
// поля условий: origin, genre, artist, album, year, addedAt, lastPlayedAt,
//               playCount, durationMs, isFavorite, isDownloaded
// операторы: eq, neq, contains, gt, lt, between, inLastDays, notInLastDays
```

Предустановленные (создаются при первом запуске, удалять их нельзя, только скрыть):

- **Недавно добавленные** — `addedAt inLastDays 30`, sort `addedAt desc`, limit 100
- **Часто слушаю** — `playCount gt 3`, sort `playCount desc`, limit 50
- **Забытые** — `lastPlayedAt notInLastDays 90 AND playCount gt 0`, limit 50
- **Избранное** — `isFavorite eq true`
- **Мои файлы** — `origin eq local`
- **Доступно офлайн** — `isDownloaded eq true`

Требования: реализовать как drift-запрос, строящийся из правила (без загрузки всей библиотеки в память); реактивно обновляться (`watch`); в UI отличать иконкой-шестерёнкой; редактор правил — простая форма «поле / оператор / значение» с кнопкой «+ условие».

### 7.3 Экспорт и импорт M3U8

- Экспорт: `#EXTM3U`, для каждого трека `#EXTINF:<секунды>,<Артист> - <Название>` + путь. Опция «относительные пути». Сохранение через `file_picker.saveFile`.
- Импорт: читаем `.m3u`/`.m3u8` (UTF-8, при ошибке — latin-1 fallback), для каждой строки ищем трек по `localPath` → по `fileHash` → по «артист + название». Не найденные — в отчёт «Не найдено: N строк», с предложением импортировать соответствующие файлы.
- Пути в Windows нормализовать (обратные слэши, регистр).

### 7.4 Очередь воспроизведения

- Действия у трека: «Играть сейчас», «Играть следующим», «В конец очереди».
- Экран очереди: текущий трек прибит сверху, остальные перетаскиваются и свайпаются.
- Shuffle не переписывает `QueueItems` — хранится отдельный порядок индексов, чтобы выключение shuffle возвращало исходный порядок.
- Repeat: off / all / one.
- Очередь и позиция трека сохраняются (throttle 5 с) и восстанавливаются при запуске в состоянии «пауза».

---

## 8. Импорт музыки с устройства

### 8.1 Способы импорта

1. **Выбрать файлы** — `FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['mp3','flac','m4a','aac','ogg','opus','wav','wma'])`.
2. **Выбрать папку** — `FilePicker.platform.getDirectoryPath()` → рекурсивный обход (глубина ≤ 10), фильтр по расширениям.
3. **Скан медиатеки (только Android)** — `on_audio_query`, под `if (Platform.isAndroid)`; на Windows пункт меню не показывать.
4. **Следить за папкой** — путь в `WatchedFolders`, пересканирование при запуске и по кнопке «Обновить»; новые файлы добавляются, исчезнувшие помечаются `isMissing = true` (не удаляются, чтобы не терять плейлисты и статистику).

### 8.2 Режим хранения (спросить один раз, менять в настройках)

- **«Ссылка на файл»** (по умолчанию на Windows): в БД `sourcePath`, файл не копируется, диск не расходуется. Риск: пользователь переместит файл → `isMissing`.
- **«Копировать внутрь приложения»** (по умолчанию на Android): файл копируется в `media/imported/`, `isCopied = true`. Надёжно, независимо от внешнего хранилища.

### 8.3 Чтение метаданных

`audio_metadata_reader` (чистый Dart → работает и на Windows):

- title, artist, album, albumArtist, genre, year, trackNo, duration, встроенная обложка (picture);
- обложка сохраняется в `media/covers/<sha1(id)>.jpg`;
- если обложки в теге нет — ищем `cover.jpg` / `folder.jpg` / `front.jpg` в папке файла;
- если тегов нет вообще — парсим имя файла по шаблонам `Артист - Название`, `NN. Название`, `NN - Артист - Название`; иначе artist = «Неизвестный исполнитель», title = имя файла без расширения;
- если `duration` не читается из тега — получить через `AudioEngine`, открыв файл (без воспроизведения).

### 8.4 Дедупликация

`fileHash = sha1(размер файла + первые 64 КБ)` — быстро и достаточно надёжно. Перед вставкой проверяем `fileHash`; при совпадении трек пропускается и учитывается как «Пропущено (дубликат)». Дополнительно нормализованное сравнение «артист + название + длительность ±2 с» — только как предупреждение, не как блокировка.

### 8.5 Процесс и UX

- Импорт в изоляте (`Isolate.run`) пачками по 50 файлов — UI не фризится на 5000 треках.
- Прогресс: «Обработано 320 из 4812 · Добавлено 298 · Пропущено 20 · Ошибок 2», кнопка «Отмена» (уже добавленное остаётся).
- Итоговый отчёт с раскрывающимся списком ошибок и кнопкой «Скопировать лог».
- После импорта — предложение «Создать плейлист из импортированного».
- Импортированные треки помечены значком «файл» и всегда доступны офлайн.

### 8.6 Разрешения Android

- Android 13+ (API 33+): `READ_MEDIA_AUDIO`; Android ≤ 12: `READ_EXTERNAL_STORAGE`. Запрашивать через `permission_handler` **только** при выборе «Скан медиатеки» или «Ссылка на файл».
- Режим «Копировать внутрь» через `file_picker` работает по SAF и **разрешений не требует** — это ещё один довод делать его дефолтом на Android.
- `MANAGE_EXTERNAL_STORAGE` не запрашивать никогда (блокирует публикацию в Play).
- При отказе в разрешении — понятный экран с кнопкой «Открыть настройки» (`openAppSettings()`).

### 8.7 Ошибки импорта

| Кейс | Поведение |
|---|---|
| Файл битый / не читается | в лог, `errors++`, импорт продолжается |
| Нет доступа к пути | понятное сообщение + подсказка про разрешения |
| Диск заполнен при копировании | остановить, удалить незавершённый файл, показать сколько нужно места |
| Файл 0 байт / длительность < 1 с | пропустить как невалидный |
| Файл удалён после импорта | `isMissing = true`, в UI серым + «Найти файл заново» / «Удалить из библиотеки» |
| Огромный файл (> 500 МБ) | предупреждение перед копированием |

---

## 9. Визуальная система: «современно и не напрягает»

### 9.1 Принципы

- **Тёмная тема по умолчанию**, низкий контраст фонов, высокий контраст только у текста и активных элементов.
- Никаких чистых `#000000` фонов и `#FFFFFF` текста в тёмной теме: фон `#101014`, текст `#E9E9EE` (кроме режима AMOLED).
- Насыщенный цвет — только акцент (play, прогресс, активный таб), максимум ~10 % площади экрана.
- Material 3, `ColorScheme.fromSeed`, скругления 16–24 px, тени мягкие и почти невидимые (`elevation ≤ 2`), разделение блоков — отступами и лёгкой прозрачностью, а не рамками.
- Типографика: Inter или Manrope через `google_fonts`. Шкала: заголовок 22/600, подзаголовок 16/500, основной 14/400, подпись 12/400. Межстрочный ≥ 1.35.
- Плотность: строка трека 64 px (Android) / 56 px (Windows), горизонтальные отступы 16 px.
- Анимации: 150–250 мс, `Curves.easeOutCubic`; переход на «Сейчас играет» — общий элемент (обложка) через `Hero`; появление списков — fade+slide 8 px через `flutter_animate`. Тумблер «Уменьшить анимации» отключает всё, кроме мгновенных переходов.
- Доступность: минимальная цель нажатия 44×44, контраст текста ≥ 4.5:1 (проверять для любого выбранного фона), поддержка системного масштаба шрифта до 1.3× без обрезки.

### 9.2 Настройки внешнего вида (экран «Оформление»)

| Настройка | Варианты | По умолчанию |
|---|---|---|
| Режим темы | Системная / Светлая / Тёмная / AMOLED (чистый чёрный) | Системная |
| Акцентный цвет | 8 предустановок + палитра-пикер | Индиго `#6C63FF` |
| «Цвет из обложки» | вкл/выкл — seed-цвет берётся из обложки текущего трека, тема плавно перекрашивается (анимация 400 мс) | Вкл |
| Фон приложения | Однотонный / Градиент (пресеты) / Встроенное изображение / **Своё фото** | Градиент |
| Размытие фона | 0–40 px | 12 px |
| Затемнение фона | 0–80 % | 45 % |
| Шрифт | Inter / Manrope / Системный | Inter |
| Скругление | Мягкое / Среднее / Прямое | Мягкое |
| Плотность списка | Компактная / Обычная | Обычная |
| Уменьшить анимации | вкл/выкл | Выкл |
| Обложка на весь экран в плеере | вкл/выкл | Выкл |

Всё хранится в `ThemeSettings` → JSON в `shared_preferences`, применяется мгновенно, без перезапуска.

### 9.3 Свой фон

- Выбор через `image_picker`, копия в `media/backgrounds/user_bg.jpg`, ресайз до максимум 1920 px по длинной стороне (экономия памяти).
- Рендер: `app_background.dart` — `Stack`: изображение (`BoxFit.cover`) → `ImageFiltered(blur)` → затемняющий градиент (`Colors.black.withValues(alpha: dim)`) → контент.
- **Обязательно:** проверка читаемости. Если средняя яркость области под текстом слишком высокая, автоматически усилить затемнение и показать подсказку «Фон затемнён для читаемости».
- Фон рисуется один раз на уровне `app.dart` (не в каждом экране) — иначе просадка производительности.
- Кнопка «Сбросить фон».

### 9.4 Цвет из обложки (без `palette_generator`)

Пакет `palette_generator` **discontinued** — использовать нельзя. Реализация на `material_color_utilities`, который уже идёт с Flutter:

```dart
// cover_color_extractor.dart
Future<Color> seedFromImage(ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = <int>[];                     // ARGB int
  // downscale: брать каждый N-й пиксель, чтобы уложиться в ~10 000 сэмплов
  final result = await QuantizerCelebi().quantize(pixels, 24);
  final ranked = Score.score(result.colorToCount);
  return Color(ranked.first);
}
```

Дальше `ColorScheme.fromSeed(seedColor: seed, brightness: ...)`. Считать в изоляте, кешировать по `trackId`, ограничивать частоту (не чаще раза на смену трека). Если извлечение не удалось — молча остаться на текущем акценте.

### 9.5 Экраны и состояния

| Экран | Содержимое | Офлайн |
|---|---|---|
| Home | подборки, «Продолжить слушать», «Недавно добавленное» | заменяется на библиотеку + мягкий баннер «Нет сети» |
| Search | debounce 400 мс, пагинация по скроллу | поле неактивно + подсказка |
| Library | табы Треки · Артисты · Альбомы · Свои файлы; поиск внутри, сортировки, множественный выбор | работает полностью |
| Playlists | сетка карточек + блок смарт-плейлистов | работает |
| Playlist detail | шапка с обложкой (collapsing app bar), кнопки Play / Shuffle / Скачать | работает |
| Import | мастер импорта, прогресс, отчёт | работает |
| Queue | текущий + очередь, drag-n-drop | работает |
| Downloads | активные / очередь / ошибки | показывает очередь, старт при появлении сети |
| Now Playing | обложка, seekbar, prev/play/next, shuffle, repeat, скорость, sleep-timer, «В плейлист» | работает |
| Settings / Оформление | см. 9.2 + качество, лимит хранилища, режим хранения импорта, размер занятого места, лицензии | работает |

- Mini-player закреплён над навигацией на всех экранах; свайп вверх → Now Playing, свайп в сторону → следующий трек.
- Пустые состояния: иконка + одна строка + одна кнопка действия (никаких «Ничего не найдено» без выхода).
- Загрузка — скелетоны, а не спиннеры по центру.
- Адаптив: ширина > 900 px (Windows) → `NavigationRail` слева + двухколоночный layout «список / детали».
- Все строки — русские, только через `lib/core/strings.dart`.

### 9.6 Дизайн-токены (единый источник, файл `lib/theme/tokens.dart`)

Никаких «магических чисел» в виджетах — только константы отсюда.

```dart
// Отступы (4-точечная сетка)
space2 = 2, space4 = 4, space8 = 8, space12 = 12, space16 = 16,
space20 = 20, space24 = 24, space32 = 32, space40 = 40

// Скругления (режимы «Мягкое» / «Среднее» / «Прямое»)
radiusSm   = 8  / 6  / 2
radiusMd   = 16 / 12 / 4
radiusLg   = 24 / 18 / 6
radiusXl   = 32 / 24 / 8
radiusPill = 999

// Тёмная тема (дефолт)
bgBase        = #101014                 // фон приложения (под фоновым изображением)
surface1      = #17171D                 // карточки
surface2      = #1F1F27                 // поднятые элементы, поля
surfaceGlass  = rgba(255,255,255,0.06)  // стеклянные панели
strokeSoft    = rgba(255,255,255,0.08)  // границы 1 px
textPrimary   = #E9E9EE
textSecondary = #A0A0AE
textTertiary  = #6E6E7C
accent        = #6C63FF                 // либо seed из обложки
accentOn      = #FFFFFF
error         = #FF6B6B

// AMOLED: bgBase = #000000, surface1 = #0A0A0C, остальное как в тёмной
// Светлая:  bgBase = #F7F7FA, surface1 = #FFFFFF, textPrimary = #14141A,
//           textSecondary = #5A5A68, strokeSoft = rgba(0,0,0,0.08)

// Типографика (Inter)
display  = 28 / w700 / letterSpacing -0.5
titleLg  = 22 / w600
titleMd  = 18 / w600
body     = 14 / w400 / height 1.4
bodyBold = 14 / w600
caption  = 12 / w400
overline = 11 / w600 / letterSpacing +0.8 / uppercase

// Длительности и кривые
durFast = 150ms, durBase = 220ms, durSlow = 400ms, durColor = 500ms
curveDefault  = Curves.easeOutCubic
curveEmphasis = Curves.easeOutBack     // только play/pause и лайк

// Размеры
tapMin = 44                            // минимальная цель нажатия
tileHeightMobile = 64, tileHeightDesktop = 56
miniPlayerHeight = 64, navBarHeight = 64
coverListSize = 48, coverCardSize = 160, coverWideSize = 260
```

Тумблер «Уменьшить анимации» → все `dur*` = `0ms`, кроме `durColor = 120ms`.

---

### 9.7 Детальный дизайн главного экрана (`home_screen.dart`)

#### Каркас

```
┌────────────────────────────────────────────────┐
│  фоновый слой: изображение → blur → затемнение │ ← app_background.dart, самый низ
│ ┌────────────────────────────────────────────┐ │
│ │ 1. Приветствие + кнопка настроек           │ │ SliverAppBar (floating)
│ │ 2. Поисковая строка-кнопка                 │ │ становится pinned при скролле
│ │ 3. Hero-блок «Продолжить слушать»          │ │
│ │ 4. Быстрые плитки 2×2                      │ │
│ │ 5. Карусель «Недавно добавленное»          │ │
│ │ 6. Карусель «Ваши плейлисты»               │ │
│ │ 7. Карусель «Смарт-подборки»               │ │
│ │ 8. Карусель «Из каталога: популярное»      │ │ скрыта офлайн
│ │ 9. Список «Слушали недавно» (5 строк)      │ │
│ │    нижний отступ: miniPlayer + navBar + 16 │ │
│ └────────────────────────────────────────────┘ │
│  mini-player (стеклянный)                      │
│  нижняя навигация / NavigationRail слева       │
└────────────────────────────────────────────────┘
```

Реализация: `CustomScrollView` + slivers. Каждый блок — отдельный виджет в `lib/features/home/sections/`, чтобы блоки можно было включать, выключать и переставлять.

#### Блок 1. Шапка

- Высота 72, горизонтальные отступы `space16`.
- Слева две строки: `overline` серым — приветствие по времени суток («Доброе утро» до 12:00, «Добрый день» до 18:00, «Добрый вечер» до 23:00, иначе «Доброй ночи»); под ним `display` — «Что послушаем?».
- Справа круглая кнопка 40×40 (`surfaceGlass`, `radiusPill`) с иконкой настроек → экран «Оформление».
- При скролле вниз > 40 px приветствие сворачивается (fade + slide −8 px, `durBase`), остаётся закреплённая поисковая строка.

#### Блок 2. Поиск

- Не `TextField`, а кнопка-заглушка: высота 48, `radiusPill`, фон `surfaceGlass`, граница `strokeSoft`, иконка поиска 20 px + текст «Поиск треков и артистов» цветом `textSecondary`. Тап → экран Search с автофокусом, переход общим элементом `Hero(tag: 'search-bar')`.
- Офлайн: прозрачность 0.4, тап → SnackBar «Поиск доступен только онлайн».

#### Блок 3. Hero «Продолжить слушать»

Показывается только если есть последний трек с позицией > 10 с и < 95 % длительности.

- Карточка на всю ширину минус 32, высота 132, `radiusLg`; фон — размытая обложка трека (blur 24) + затемнение 55 % + граница `strokeSoft`.
- Внутри: обложка 92×92 (`radiusMd`) слева; справа `overline` «Продолжить слушать», `titleMd` название (1 строка, ellipsis), `body` артист цветом `textSecondary`.
- Справа снизу круглая кнопка Play 48×48 в акценте, тень акцентом (blur 16, alpha 0.35).
- Под текстом полоса прогресса 2 px (`accent` на `strokeSoft`) и `caption` «Осталось 2:14».
- Тап → возобновить с сохранённой позиции и открыть Now Playing.
- Обложка обёрнута в `Hero(tag: 'cover-<trackId>')` — тот же тег, что в mini-player и плеере.

#### Блок 4. Быстрые плитки

- Сетка 2×2, `childAspectRatio: 1.9`, зазор `space12`.
- Плитки: «Мои файлы», «Скачанное», «Избранное», «Импорт».
- Плитка: `surface1` + `strokeSoft`, `radiusMd`, иконка 20 px в круге 32 (`accent` с alpha 0.15), рядом `bodyBold` название и `caption` с числом («248 треков»). Числа — реактивными count-запросами, не выборкой всех строк.
- Нажатие: масштаб 0.97 за `durFast`.

#### Блоки 5–8. Карусели

Общий виджет `SectionCarousel`:

- Заголовок секции `titleMd`, справа текстовая кнопка «Все» (`bodyBold`, `accent`); отступ слева `space16`, снизу `space12`.
- Горизонтальный `ListView.builder`, `BouncingScrollPhysics`, `padding: horizontal 16`, зазор `space12`, `cacheExtent: 600`.
- Карточка трека: обложка 160×160 (`radiusMd`, `cacheWidth: 320`), ниже `bodyBold` название (до 2 строк) и `caption` артист. Ширина карточки 160.
- В правом нижнем углу обложки бейдж состояния 20×20 на фоне `rgba(0,0,0,0.55)`: галочка — доступно офлайн, иконка файла — `origin == local`, кольцо прогресса — качается.
- Долгое нажатие → bottom sheet: «Играть следующим», «В конец очереди», «В плейлист», «Скачать», «В избранное», «Об авторе и лицензии».
- Блок 6 «Ваши плейлисты»: карточки 160×160 с мозаикой 2×2, снизу градиент и название; первая карточка — пунктирная «+ Создать плейлист».
- Блок 7 «Смарт-подборки»: карточки 200×112, градиент на основе акцента (свой оттенок у каждой), иконка, название, `caption` с количеством.
- Блок 8 «Из каталога» — только онлайн. Офлайн вместо него карточка-баннер (высота 88, `surface1`): иконка облака, «Нет подключения», `caption` «Показываем то, что уже на устройстве». Без кнопок и без красного цвета.

#### Блок 9. «Слушали недавно»

Вертикальный список из 5 строк `TrackTile` + текстовая кнопка «Показать всё».

#### `TrackTile` (общий виджет)

- Высота 64 (мобайл) / 56 (десктоп), отступы 16 / 8.
- Обложка 48×48, `radiusSm`; у играющего трека — акцентная рамка 2 px и мини-эквалайзер из 3 полосок (цикл 900 мс, замирает на паузе).
- Центр: `bodyBold` название (1 строка) + `caption` «Артист · 3:24». У активного трека название в `accent`.
- Справа: кнопка 40×40 (скачать / прогресс / галочка), затем «⋮».
- Свайп влево — «В очередь», свайп вправо — «В избранное» (только мобайл, иконка на цветном фоне).
- В режиме множественного выбора обложка заменяется чекбоксом, шапка превращается в панель действий.

#### Состояния главного экрана

| Состояние | Что показываем |
|---|---|
| Первый запуск, библиотека пуста | Hero скрыт; карточка-онбординг высотой 180: «Начните с музыки» + кнопки «Найти в каталоге» и «Импортировать свои файлы» |
| Загрузка | скелетоны: прямоугольник 132, 4 плитки, 2 ряда по 3 карточки 160×160; shimmer 1.2 с |
| Офлайн | блок 8 скрыт, вместо него баннер; остальное работает |
| Ошибка каталога | в блоке 8 строка «Не удалось загрузить подборки» + «Повторить»; остальные блоки не затронуты |
| Pull-to-refresh | `RefreshIndicator` обновляет блоки 5–8, офлайн — только локальные данные |

#### Windows / ширина > 900 px

- `NavigationRail` слева (72 px; при ширине > 1200 px — расширенный 220 px с подписями).
- Контент в контейнере `maxWidth: 1200`, по центру.
- Карусели превращаются в сетки: 5–7 карточек в ряд, прокрутка колесом (`Shift + wheel`), кнопки-стрелки по краям появляются на hover.
- Hover: карточка поднимается на 2 px, обложка светлеет на 4 %, по центру обложки появляется кнопка Play (fade `durFast`).
- Mini-player не «плавающий», а закреплён строкой во всю ширину окна (высота 72).

---

### 9.8 Детальный дизайн экрана плеера (`now_playing_screen.dart`)

Открывается полноэкранным маршрутом снизу вверх (`durSlow`, `curveDefault`) либо перетаскиванием mini-player вверх — жест напрямую управляет прогрессом анимации.

#### Каркас (мобайл)

```
┌──────────────────────────────────────┐
│ 1. Ручка-«таблетка» + шапка          │  56
│ 2. Обложка (квадрат)                 │  ширина − 48
│ 3. Название · артист · лайк/плейлист │  ~72
│ 4. Прогресс + время                  │  ~44
│ 5. Основные кнопки управления        │  ~88
│ 6. Дополнительная панель             │  ~56
│ 7. «Далее в очереди» (свайп вверх)   │  peek 72
└──────────────────────────────────────┘
```

Фон: обложка текущего трека `BoxFit.cover`, blur 40, поверх вертикальный градиент от `rgba(0,0,0,0.35)` сверху до `rgba(0,0,0,0.85)` снизу. Смена трека — кросс-фейд фона `durSlow`. При включённом «Цвете из обложки» тема экрана перекрашивается за `durColor`.

#### 1. Шапка

- Сверху по центру ручка 36×4, `radiusPill`, белая с alpha 0.3.
- Слева кнопка «свернуть» (шеврон вниз, 40×40); по центру `overline` с контекстом воспроизведения («Из плейлиста · Вечерний чил» / «Из каталога» / «Мои файлы»); справа «⋮» — меню трека.

#### 2. Обложка

- Квадрат, сторона = ширина экрана − 48, максимум 420, `radiusXl`; тень blur 40, смещение по Y 16, цвет — доминирующий цвет обложки с alpha 0.45.
- `Hero(tag: 'cover-<trackId>')` — общий элемент с mini-player и главным экраном.
- Смена трека: текущая обложка уходит на −24 px по X с fade, новая приходит с +24 px, `durBase`.
- Жесты: свайп влево — следующий, вправо — предыдущий (порог 25 % ширины, иначе возврат с пружиной); двойной тап — лайк с анимацией сердца (0.6 → 1.15 → 1, `curveEmphasis`); одиночный тап — режим «обложка на весь экран», если включён в настройках.
- Во время буферизации — тонкое пульсирующее кольцо по контуру обложки, без спиннера по центру.

#### 3. Метаданные

- Название: `display`, 1 строка; если не влезает — плавная бегущая строка (пауза 2 с, скорость 30 px/с, цикл). Реализовать через `AnimationController`, пакет `marquee` не использовать.
- Артист: `body`, `textSecondary`; тап → страница артиста (его треки в библиотеке).
- Справа в ряд кнопки 44×44: «сердце» (лайк, заливка с `curveEmphasis`) и «плюс» (в плейлист).
- Чип состояния (высота 22, `radiusPill`, `surfaceGlass`, `caption`): «Мой файл» для `origin == local`, «Онлайн» для стрима, галочка «Офлайн» для скачанного.

#### 4. Прогресс

- Кастомный слайдер: дорожка 4 px (`radiusPill`), заполнение — акцент, буфер — белый alpha 0.15, бегунок 12 px; при перетаскивании бегунок растёт до 18, дорожка до 6 (`durFast`).
- Во время перетаскивания над бегунком всплывает подсказка со временем (`caption`, `surface2`, `radiusSm`).
- Под слайдером: слева текущее время, справа длительность (`caption`, `textTertiary`), обязательно `fontFeatures: [FontFeature.tabularFigures()]` — иначе цифры дёргаются.
- Тап по дорожке — мгновенный seek. Обновление позиции — не чаще 4 раз в секунду.

#### 5. Основные кнопки

Ряд из 5 элементов, `spaceBetween`, горизонтальные отступы 24:

| Элемент | Размер | Поведение |
|---|---|---|
| Shuffle | 44 | выкл — `textSecondary`; вкл — `accent` + точка 4 px под иконкой |
| Prev | 52 | тап — предыдущий трек (если позиция < 3 с) либо в начало текущего; удержание — перемотка назад ×4 |
| Play / Pause | 72 | круг, залит `accent`, иконка 32 `accentOn`, тень акцентом (blur 24, alpha 0.4); морфинг через `AnimatedIcon`, `durFast`, `curveEmphasis`; нажатие 0.92 → 1 |
| Next | 52 | тап — следующий; удержание — перемотка вперёд ×4 |
| Repeat | 44 | цикл off → all → one; в режиме one — цифра «1» в иконке |

У всех кнопок `tooltip` (для Windows) и haptic на мобайле (`HapticFeedback.selectionClick()`).

#### 6. Дополнительная панель

Ряд иконок 40×40, `textSecondary`, активные — `accent`:

- Скорость → лист 0.5×…2.0× шагом 0.25 + «Сброс»
- Sleep-timer → лист 15 / 30 / 45 / 60 мин, «В конце трека», «Отключить»; при активном таймере под иконкой обратный отсчёт
- Текст трека — иконка показывается только если текст пришёл из API (не «серая заглушка»)
- Эквалайзер — только Android, на Windows не рендерить
- «Очередь» → экран очереди
- «Об авторе и лицензии» — обязательно для CC-треков: имя автора + ссылка `license_ccurl`

#### 7. «Далее в очереди»

- Внизу закреплён peek 72 px: `overline` «Далее в очереди», обложка 40×40 и название следующего трека.
- Свайп вверх по блоку раскрывает лист с очередью на 70 % высоты (стеклянный фон, drag-n-drop, свайп-удаление) без выхода из плеера.
- Пустая очередь → блок скрыт, а не показывает пустое место.

#### Раскладка Windows / ширина > 900 px

- Две колонки: слева обложка (максимум 420, по центру), справа метаданные, прогресс, кнопки и сразу развёрнутая очередь. `maxWidth` контента 1100.
- Плеер открывается не полноэкранным листом, а как правая область или диалог 1000×640 — в зависимости от ширины окна.
- Горячие клавиши через `Shortcuts` + `Actions` (не `RawKeyboardListener`): `Space` — play/pause, `←/→` — ±5 с, `Ctrl+←/→` — трек назад/вперёд, `↑/↓` — громкость, `L` — лайк, `S` — shuffle, `R` — repeat, `Esc` — закрыть.
- Добавить регулятор громкости (на мобайле не нужен — там системные кнопки).

### 9.9 Mini-player (`mini_player.dart`)

- Высота 64, отступы 12 от краёв, `radiusLg`, фон `surfaceGlass` + `BackdropFilter(blur: 24)` + граница `strokeSoft`. Закреплён над навигацией на всех экранах, кроме самого плеера.
- Содержимое: обложка 44×44 (`radiusSm`, `Hero`) → название и артист (по одной строке) → prev (только десктоп) → play/pause 40 → next 40.
- По верхней кромке — линия прогресса 2 px во всю ширину (`accent`).
- Жесты: тап или свайп вверх → Now Playing; свайп влево/вправо → следующий/предыдущий; свайп вниз → остановить и скрыть (с Undo в SnackBar).
- Появление/исчезновение: slide снизу + fade, `durBase`. Когда ничего не играет — `SizedBox.shrink()`, место не занимает.

### 9.10 Требования к реализации (критично для качества)

- Позицию воспроизведения подписывать **только** в виджетах прогресса и времени (узкий `Consumer`). Перестраивать весь экран 4 раза в секунду запрещено.
- Обложку декодировать один раз с `cacheWidth` под фактический размер; фон плеера использует тот же `ImageProvider`, файл не читается дважды.
- Не больше двух `BackdropFilter` одновременно на экране — это дорого. Фон плеера делать заранее размытым изображением, а не живым `BackdropFilter`.
- Кнопка play/pause реагирует мгновенно (оптимистичное состояние), даже если движок отвечает с задержкой.
- Все размеры, цвета и длительности — только из `tokens.dart`.

---

## 10. Платформенная настройка

### 10.1 Android
- `minSdk 23`, `targetSdk 35`, `compileSdk 35`.
- Манифест:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
                 android:maxSdkVersion="32"/>
```
внутри `<application>`:
```xml
<service android:name="com.ryanheise.audioservice.AudioService"
         android:foregroundServiceType="mediaPlayback"
         android:exported="true">
  <intent-filter><action android:name="android.media.browse.MediaBrowserService"/></intent-filter>
</service>
<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true">
  <intent-filter><action android:name="android.intent.action.MEDIA_BUTTON"/></intent-filter>
</receiver>
```
- `MainActivity extends AudioServiceActivity`.
- `MANAGE_EXTERNAL_STORAGE` — запрещено.
- В `main()`:
```dart
await JustAudioBackground.init(
  androidNotificationChannelId: 'com.example.offlinetunes.channel.audio',
  androidNotificationChannelName: 'Воспроизведение',
  androidNotificationOngoing: true,
);
```

### 10.2 Windows
- `flutter config --enable-windows-desktop`.
- `windows/runner/Runner.rc` — название, версия, копирайт; иконка `windows/runner/resources/app_icon.ico`.
- SQLite тянется через `sqlite3_flutter_libs`, DLL руками не кладём.
- `file_picker` и `image_picker` на Windows работают без доп. настройки; `on_audio_query` **не вызывать**.
- Минимальный размер окна 480×720 (иначе layout ломается).

---

## 11. Обработка ошибок (обязательный список)

1. Нет интернета при поиске → сообщение + «Повторить».
2. Обрыв сети во время загрузки → `paused`, автоматический resume при возврате сети.
3. Диск заполнен → `StorageFailure`, понятное сообщение, `.part` удаляется.
4. 403/404 на URL загрузки (истёк линк) → перезапросить через `byId()`, обновить URL, повторить один раз.
5. Битый локальный файл → `localPath = null`, предложить перекачать.
6. Файл удалён извне → при старте `verifyLibrary()`, `isMissing = true`, в UI серым.
7. 429 от API → backoff + «Слишком много запросов, попробуйте позже».
8. Приложение убито во время загрузки → очередь восстановлена из `Downloads`.
9. Импорт: битый файл / нет прав / дубликат / 0 байт → см. 8.7.
10. Плейлист ссылается на `isMissing` трек → трек показан серым, при Play пропускается с тостом «Пропущено: файл не найден».
11. Своё фоновое фото удалено или не читается → откат на градиент по умолчанию.
12. Повреждённый JSON настроек темы → сброс к дефолту, без краша.

---

## 12. Производительность (обязательные требования)

- Библиотека 10 000 треков: списки только через `ListView.builder` с `itemExtent`; запросы к БД — с `limit/offset` пагинацией по 100.
- Поиск по библиотеке — SQL `LIKE` с индексом (или FTS5), debounce 300 мс, не фильтрация списка в Dart.
- Обложки: `cached_network_image` для сетевых, `Image.file` + `cacheWidth` для локальных; в списках грузить в разрешении ≤ 128 px.
- Импорт и извлечение цвета — в изоляте.
- Запись прогресса загрузки и позиции воспроизведения — throttle (250 мс / 5 с).
- Цель: плавные 60 fps при скролле списка из 5000 треков на среднем Android.

---

## 13. Что запрещено делать исполнителю

- Придумывать API пакетов «по памяти» — сверять с pub.dev.
- Использовать `palette_generator` (discontinued) или `on_audio_query` на Windows.
- Оставлять `TODO`, заглушки, «здесь будет реализация».
- Хранить аудио в общей галерее / `MediaStore` / на рабочем столе.
- Запрашивать `MANAGE_EXTERNAL_STORAGE` или разрешения на storage, когда они не нужны.
- Класть `client_id` в git: только `--dart-define=JAMENDO_CLIENT_ID=...` + `String.fromEnvironment`.
- `setState` для состояния плеера/темы — только Riverpod.
- Блокировать UI-поток файловыми операциями, импортом, обработкой изображений.
- Реализовывать загрузку из сервисов, где это запрещено правилами (см. 3.4).
- Добавлять пакеты вне списка раздела 2 без явного согласования.
- Хардкодить размеры, цвета, радиусы и длительности в виджетах — только `tokens.dart`.
- Реализовывать бегущую строку сторонним пакетом — только `marquee_text.dart` на `AnimationController`.
- Перестраивать экран плеера целиком на каждый тик позиции.

---

## 14. Порядок реализации (после каждого этапа — рабочая сборка)

1. **Каркас:** проект, pubspec, адаптивная навигация, заглушки экранов. Запускается на Android и Windows.
2. **Тема и визуал:** `tokens.dart` (9.6), `app_theme`, `theme_controller`, `ThemeSettings`, экран «Оформление», `app_background`, `glass_surface`, `skeleton`, `empty_state`. (Делаем рано — иначе потом переписывать все экраны.)
3. **БД:** таблицы, `build_runner`, миграции, smoke-тест.
4. **Источник:** `MusicSource` + `JamendoSource` + маппинг + тест на моке. Search показывает реальные треки.
5. **Плеер:** `AudioEngine`, `PlaybackService`, затем UI строго по 9.8–9.9: mini-player, Now Playing (обложка + Hero, `progress_bar`, `player_controls`, `extra_actions_row`), стрим по URL.
6. **Фон (Android):** `just_audio_background`, уведомление, кнопки, экран блокировки.
7. **Загрузки:** `FileStorage`, `DownloadManager`, очередь, прогресс, resume.
8. **Офлайн:** `resolvePlayableUri`, Library, `verifyLibrary()`, тест в авиарежиме.
9. **Импорт с устройства:** `metadata_reader` → `local_import_service` → экран импорта → дедуп → `WatchedFolders` → скан MediaStore на Android.
10. **Плейлисты:** CRUD, обложки, reorder, «В плейлист», «Скачать плейлист».
11. **Смарт-плейлисты + M3U:** правила, построитель запросов, редактор, экспорт/импорт.
12. **Очередь:** `queue_controller`, экран очереди, persist, shuffle/repeat, sleep-timer.
13. **Главный экран целиком по 9.7:** все 9 блоков, скелетоны, офлайн-баннер, онбординг-карточка, десктопная раскладка.
14. **Цвет из обложки**, `up_next_peek`, горячие клавиши Windows, полировка анимаций, все кейсы из раздела 11.
15. **Релиз:** сборки и установщик (раздел 16).

---

## 15. Критерии приёмки

**База**
- [ ] `flutter analyze` — 0 ошибок, 0 warning; `flutter test` — всё зелёное.
- [ ] Собирается `flutter build apk --release` и `flutter build windows --release`.
- [ ] Поиск возвращает реальные треки, обложки отображаются.
- [ ] Скачивание: прогресс идёт, размер файла совпадает с ожидаемым.
- [ ] **Авиарежим:** библиотека полна, трек играет, обложка видна, seek работает.
- [ ] Android: свёрнутое приложение играет, уведомление управляет плеером.
- [ ] Убийство приложения во время загрузки → задача восстановлена и докачивается.
- [ ] Windows-установщик ставится на чистую машину без Flutter SDK, приложение запускается.

**Плейлисты**
- [ ] Создание, переименование, удаление, дублирование, своя обложка, мозаика при её отсутствии.
- [ ] Порядок треков сохраняется после перезапуска; Undo при удалении трека работает.
- [ ] Повторное добавление трека не создаёт дубликат.
- [ ] «Скачать плейлист» ставит в очередь только недостающие и разрешённые треки.
- [ ] Все 6 смарт-плейлистов возвращают корректные наборы и обновляются сами после прослушивания/добавления трека.
- [ ] Экспорт M3U8 → импорт того же файла восстанавливает состав 1:1.
- [ ] Очередь и позиция восстанавливаются после перезапуска; выключение shuffle возвращает исходный порядок.

**Импорт**
- [ ] Импорт 500+ файлов из папки: UI не фризится, прогресс идёт, отмена работает.
- [ ] Теги, год, жанр, номер трека и встроенная обложка читаются; при отсутствии тегов работает парсинг имени файла.
- [ ] Повторный импорт той же папки добавляет 0 треков (все как дубликаты).
- [ ] Оба режима хранения работают; «копировать внутрь» не требует разрешений на Android.
- [ ] Перемещение файла вне приложения → трек помечен `isMissing`, приложение не падает, плейлисты целы.
- [ ] Скан медиатеки работает на Android и полностью отсутствует в UI на Windows.
- [ ] Импортированный трек играет в авиарежиме и добавляется в плейлист.

**Главный экран (9.7)**
- [ ] Все 9 блоков на месте и в заданном порядке; отступы и размеры взяты из `tokens.dart`.
- [ ] «Продолжить слушать» появляется только при позиции > 10 с и < 95 %, тап возобновляет с той же секунды.
- [ ] При скролле приветствие сворачивается, поисковая строка закрепляется сверху.
- [ ] Тап по поиску открывает Search с автофокусом, обложка/строка переходят общим элементом без «прыжка».
- [ ] Бейджи на карточках корректно различают «офлайн», «мой файл» и «качается».
- [ ] Пустая библиотека → онбординг-карточка; офлайн → блок каталога заменён баннером без красного цвета.
- [ ] Pull-to-refresh обновляет только сетевые блоки и не роняет экран офлайн.
- [ ] Ширина > 900 px: NavigationRail, контент ≤ 1200 px, hover-эффекты и кнопка Play на обложке.

**Экран плеера (9.8–9.9)**
- [ ] Обложка переходит из mini-player в плеер общим элементом (`Hero`) плавно, без мигания.
- [ ] Свайпы по обложке переключают треки, недотянутый свайп возвращается с пружиной.
- [ ] Двойной тап ставит лайк с анимацией; повторный снимает.
- [ ] Слайдер: буфер виден, подсказка со временем при перетаскивании, цифры не дёргаются (tabular figures).
- [ ] Удержание prev/next перематывает ×4, короткий тап переключает трек.
- [ ] Play/pause отвечает мгновенно, иконка морфится, а не подменяется рывком.
- [ ] Sleep-timer и скорость работают и показывают текущее состояние на иконке.
- [ ] «Далее в очереди» раскрывается свайпом, пустая очередь скрывает блок.
- [ ] Для CC-трека доступны имя автора и рабочая ссылка на лицензию.
- [ ] Windows: двухколоночная раскладка, работают все горячие клавиши, есть громкость; эквалайзер отсутствует.
- [ ] Профилирование: на экране плеера не более двух `BackdropFilter`; при воспроизведении перестраиваются только виджеты прогресса и времени (проверить через `debugProfileBuildsEnabled` / Flutter DevTools).

**Визуал**
- [ ] Переключение темы, акцента, шрифта, скругления, плотности применяется мгновенно и сохраняется.
- [ ] Своё фото как фон: размытие и затемнение регулируются, текст читаем, сброс работает.
- [ ] «Цвет из обложки» перекрашивает тему при смене трека, не тормозит и не мигает.
- [ ] «Уменьшить анимации» действительно отключает анимации.
- [ ] Системный масштаб шрифта 1.3× не ломает layout; контраст текста ≥ 4.5:1.
- [ ] Скролл списка 5000 треков — без заметных фризов.
- [ ] Windows при ширине > 900 px использует NavigationRail; окно 480×720 не ломает верстку.

---

## 16. Сборка

### Android
```bash
flutter build apk --release --split-per-abi
flutter build appbundle --release
```
Подпись: `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) + `signingConfigs.release`. Ключ **не коммитить**, добавить в `.gitignore`.

### Windows → один .exe
```bash
flutter build windows --release
# результат: build/windows/x64/runner/Release/ (offlinetunes.exe + DLL + data/)
iscc installer\windows_installer.iss
```

```iss
; installer/windows_installer.iss
[Setup]
AppName=OfflineTunes
AppVersion=1.1.0
DefaultDirName={autopf}\OfflineTunes
DefaultGroupName=OfflineTunes
OutputBaseFilename=OfflineTunes-Setup-1.1.0
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
SetupIconFile=..\windows\runner\resources\app_icon.ico

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\OfflineTunes"; Filename: "{app}\offlinetunes.exe"
Name: "{autodesktop}\OfflineTunes"; Filename: "{app}\offlinetunes.exe"

[Run]
Filename: "{app}\offlinetunes.exe"; Description: "Запустить OfflineTunes"; Flags: nowait postinstall skipifsilent
```

> `offlinetunes.exe` из папки Release **не работает без** соседних DLL и папки `data`. «Один файл» получается только через установщик (Inno Setup / MSIX) — portable single-exe без упаковки не обещать.

---

## 17. Промпт для Gemini (вставить вместе с этим файлом)

```
Ты — senior Flutter-разработчик. Ниже техническое задание (карта проекта v1.1) на приложение
OfflineTunes: офлайн-плеер с онлайн-каталогом, плейлистами, импортом музыки с устройства
и настраиваемым визуалом. Реализуй его ПОЛНОСТЬЮ и БЕЗ заглушек, соблюдая стек,
версии пакетов и структуру папок буквально.

Работай этапами из раздела 14. На каждом этапе:
1) перечисли файлы, которые создаёшь/меняешь;
2) выдай ПОЛНЫЙ код каждого файла (без "...", без сокращений, с импортами);
3) укажи команды терминала для проверки;
4) сверься с критериями приёмки из раздела 15, которые относятся к этому этапу;
5) остановись и жди моего "ок", прежде чем идти дальше.

Жёсткие правила:
- Не добавляй пакетов вне списка раздела 2. НЕ используй palette_generator (он discontinued) —
  цвет из обложки только через material_color_utilities.
- on_audio_query вызывай только под if (Platform.isAndroid).
- Если точный API пакета тебе неизвестен — скажи об этом и предложи сверку, не выдумывай метод.
- Никаких TODO и псевдокода в финальных файлах.
- Все пользовательские строки — на русском, через lib/core/strings.dart.
- Тяжёлые операции (импорт, извлечение цвета, обработка изображений) — в изоляте.
- Главный экран и плеер собирай ровно по разделам 9.7–9.9: те же блоки, размеры, жесты и состояния.
  Все константы — из lib/theme/tokens.dart, магических чисел в виджетах быть не должно.
- Код должен проходить flutter analyze без предупреждений.
Начни с этапа 1.
```

---

## 18. Ссылки

- Jamendo API, метод tracks (поля `audio`, `audiodownload`, `audiodownload_allowed`): https://developer.jamendo.com/v3.0/tracks
- Документация Jamendo API: https://developer.jamendo.com/v3.0/docs
- Audius, поиск треков: https://docs.audius.co/developers/api/search-tracks/ · разработчикам: https://docs.audius.co/
- just_audio 0.10.6: https://pub.dev/packages/just_audio
- audio_service 0.18.19: https://pub.dev/packages/audio_service
- drift 2.34.4: https://pub.dev/packages/drift
- flutter_riverpod 3.4.3: https://pub.dev/packages/flutter_riverpod
- dio 5.11.1: https://pub.dev/packages/dio
- file_picker 12.2.0 (Android + Windows + desktop): https://pub.dev/packages/file_picker
- audio_metadata_reader 1.4.2 (ID3 / Vorbis / iTunes-теги, чистый Dart): https://pub.dev/packages/audio_metadata_reader
- on_audio_query 2.9.0 (Android / iOS / Web — **не Windows**): https://pub.dev/packages/on_audio_query
- permission_handler 13.0.2: https://pub.dev/packages/permission_handler
- image_picker 1.2.3 (Android 24+, Windows 10+): https://pub.dev/packages/image_picker
- shared_preferences 2.5.5: https://pub.dev/packages/shared_preferences
- google_fonts 8.2.1: https://pub.dev/packages/google_fonts
- flutter_animate 4.5.2: https://pub.dev/packages/flutter_animate
- palette_generator — **discontinued, не использовать**: https://pub.dev/packages/palette_generator
- media_kit 1.2.6 (резервный аудиодвижок для Windows): https://pub.dev/packages/media_kit
