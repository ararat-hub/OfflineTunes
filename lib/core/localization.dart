import 'package:flutter/widgets.dart';
import 'localization_additional.dart';
import 'localization_de_fr.dart';

extension OfflineTunesLocalization on BuildContext {
  String tr(String source, [Map<String, Object> arguments = const {}]) {
    final translation = _translations[source];
    final additional = additionalLanguages[source];
    final language = Localizations.localeOf(this).languageCode;
    final message = switch (language) {
      'en' => translation?.$1 ?? source,
      'es' => translation?.$2 ?? source,
      'de' => germanFrench[source]?.$1 ?? translation?.$1 ?? source,
      'fr' => germanFrench[source]?.$2 ?? translation?.$1 ?? source,
      'uk' => additional?.$1 ?? translation?.$1 ?? source,
      'pl' => additional?.$2 ?? translation?.$1 ?? source,
      'pt' => additional?.$3 ?? translation?.$1 ?? source,
      'it' => additional?.$4 ?? translation?.$1 ?? source,
      'tr' => additional?.$5 ?? translation?.$1 ?? source,
      _ => source,
    };
    if (arguments.isEmpty) return message;
    return message.replaceAllMapped(_placeholder, (match) {
      return arguments[match[1]]?.toString() ?? match[0]!;
    });
  }
}

final _placeholder = RegExp(r'\{(\w+)\}');

const _translations = <String, (String, String)>{
  'Язык интерфейса': ('Interface language', 'Idioma de la interfaz'),
  'Найти язык': ('Find a language', 'Buscar idioma'),
  'Записи из музыкальных каталогов': (
    'From music catalogs',
    'De catálogos musicales'
  ),
  'Доступно в oTune': ('Available in oTune', 'Disponible en oTune'),
  'Открыть в {provider}': ('Open in {provider}', 'Abrir en {provider}'),
  'Мир': ('Global', 'Global'),
  'Россия': ('Russia', 'Rusia'),
  'Топ треков в России': ('Top tracks in Russia', 'Top canciones en Rusia'),
  'Популярные совпадения': ('Popular matches', 'Resultados populares'),
  'Найденные треки': ('Matching tracks', 'Canciones encontradas'),
  'Подборка · Apple Music': (
    'Results · Apple Music',
    'Resultados · Apple Music'
  ),
  'По популярности · Deezer': (
    'By popularity · Deezer',
    'Por popularidad · Deezer'
  ),
  'Чарт · Apple Music': ('Chart · Apple Music', 'Lista · Apple Music'),
  'Сохранённая подборка · {provider}': (
    'Saved chart · {provider}',
    'Lista guardada · {provider}'
  ),
  'Скачать обновление': ('Download update', 'Descargar actualización'),
  'Сохранённые фоны виджета': (
    'Saved widget backgrounds',
    'Fondos guardados del widget'
  ),
  'Сохранённые фоны плеера': (
    'Saved player backgrounds',
    'Fondos guardados del reproductor'
  ),
  'Для загрузки нужна прямая HTTPS-ссылка на аудиофайл.': (
    'Enter a direct HTTPS link to an audio file to download it.',
    'Introduce un enlace HTTPS directo a un archivo de audio.'
  ),
  'Ссылку YouTube можно воспроизвести здесь. Для офлайн-загрузки нужен аудиофайл.':
      (
    'Play this YouTube link here. To download for offline listening, use an audio file.',
    'Reproduce aquí este enlace de YouTube. Para escuchar sin conexión, descarga un archivo de audio.'
  ),
  'Карточка Android': ('Android media card', 'Tarjeta multimedia de Android'),
  'Использовать обложку трека': (
    'Use track artwork',
    'Usar la portada de la pista'
  ),
  'Использовать свой фон в карточке Android': (
    'Use custom artwork in the Android media card',
    'Usar una imagen personalizada en la tarjeta multimedia de Android'
  ),
  'Шторка уведомлений и экран блокировки используют обложку трека или выбранное изображение. Android задаёт размер и расположение кнопок.':
      (
    'The notification shade and lock screen use track artwork or the selected image. Android controls the size and button layout.',
    'Las notificaciones y la pantalla de bloqueo usan la portada o la imagen elegida. Android determina el tamaño y la posición de los botones.'
  ),
  'Для видео в карточке используется кадр.': (
    'The media card uses a still frame from your video.',
    'La tarjeta usa un fotograma del vídeo.'
  ),
  'Выбрать фон карточки': (
    'Choose card artwork',
    'Elegir imagen de la tarjeta'
  ),
  'Дата и время': ('Date and time', 'Fecha y hora'),
  'Часовой пояс': ('Time zone', 'Zona horaria'),
  'Как на устройстве': (
    'Use device time zone',
    'Usar zona horaria del dispositivo'
  ),
  'Найти часовой пояс': ('Find a time zone', 'Buscar zona horaria'),
  'Скачать': ('Download', 'Descargar'),
  'Скачано': ('Downloaded', 'Descargado'),
  'Не удалось открыть загрузки.': (
    'Could not open downloads.',
    'No se pudieron abrir las descargas.'
  ),
  'Скачивание': ('Downloading', 'Descargando'),
  'Удалить загрузку': ('Remove download', 'Eliminar descarga'),
  'Не удалось скачать трек.': (
    'Could not download the track.',
    'No se pudo descargar la pista.'
  ),
  'Не удалось удалить загрузку.': (
    'Could not remove the download.',
    'No se pudo eliminar la descarga.'
  ),
  'Скачайте доступные треки через поиск или подборки, чтобы слушать их без интернета.':
      (
    'Download available tracks from Search or Discover to listen offline.',
    'Descarga pistas de Buscar o Descubrir para escucharlas sin conexión.'
  ),
  'О треке': ('Track details', 'Información de la pista'),
  'Сейчас играет': ('Now playing', 'Sonando ahora'),
  'По времени': ('By date', 'Por fecha'),
  'По названию': ('By title', 'Por título'),
  'Сохранить виджет': ('Save widget', 'Guardar widget'),
  'Сохранённые виджеты': ('Saved widgets', 'Widgets guardados'),
  'Виджет плеера': ('Player widget', 'Widget del reproductor'),
  'Открыть виджет': ('Open widget', 'Abrir widget'),
  'Компактный плеер с отдельным фоном и сохранёнными стилями.': (
    'A compact player with its own background and saved styles.',
    'Un reproductor compacto con su propio fondo y estilos guardados.'
  ),
  'Добавить с устройства': ('Add from device', 'Añadir del dispositivo'),
  'Выбрать аудиофайлы': ('Choose audio files', 'Elegir archivos de audio'),
  'Полные треки · Audius': (
    'Full tracks · Audius',
    'Pistas completas · Audius'
  ),
  'В вашей медиатеке': ('In your library', 'En tu biblioteca'),
  'Полные записи · Wikimedia Commons': (
    'Full recordings · Wikimedia Commons',
    'Grabaciones completas · Wikimedia Commons'
  ),
  'Каталог временно недоступен.': (
    'The catalogue is temporarily unavailable.',
    'El catálogo no está disponible temporalmente.'
  ),
  'Ещё результаты': ('More results', 'Más resultados'),
  'Источник записи': ('Recording source', 'Fuente de la grabación'),
  'Недавно прослушанные': ('Recently played', 'Reproducidas recientemente'),
  'Все треки': ('All tracks', 'Todas las pistas'),
  'Здесь появятся прослушанные треки.': (
    'Tracks you play will appear here.',
    'Las pistas que reproduzcas aparecerán aquí.'
  ),
  'Убрать из избранного': ('Remove from favorites', 'Quitar de favoritos'),
  'В избранное': ('Add to favorites', 'Añadir a favoritos'),
  'Рекомендации': ('Recommendations', 'Recomendaciones'),
  'Подборки': ('Discover', 'Descubrir'),
  'Для вас': ('For you', 'Para ti'),
  'Популярное': ('Popular', 'Popular'),
  'Часто слушаете': ('On repeat', 'En repetición'),
  'По числу прослушиваний · Audius': (
    'Ranked by plays · Audius',
    'Por reproducciones · Audius'
  ),
  'Последняя сохранённая подборка Audius': (
    'Last saved Audius chart',
    'Última lista guardada de Audius'
  ),
  'Прослушиваний: {count}': ('Plays: {count}', 'Reproducciones: {count}'),
  'Здесь появятся треки, которые вы слушали несколько раз.': (
    'Tracks you play more than once will appear here.',
    'Aquí aparecerán las pistas que escuches más de una vez.',
  ),
  'Повторить': ('Retry', 'Reintentar'),
  'Слушайте музыку или добавляйте треки в избранное, чтобы увидеть рекомендации из медиатеки.':
      (
    'Play music or add tracks to favorites for recommendations from your library.',
    'Escucha música o añade pistas a favoritos para recibir recomendaciones de tu biblioteca.'
  ),
  'Загрузки': ('Downloads', 'Descargas'),
  'Загрузки появятся в мобильной версии.': (
    'Downloads are planned for the mobile version.',
    'Las descargas están previstas para la versión móvil.'
  ),
  'Звук': ('Sound', 'Sonido'),
  'Эквалайзер для аудиотреков': (
    'Audio track equalizer',
    'Ecualizador de pistas'
  ),
  'Ровный': ('Flat', 'Plano'),
  'Больше баса': ('Bass boost', 'Refuerzo de graves'),
  'Голос': ('Voice', 'Voz'),
  'Яркий': ('Bright', 'Brillante'),
  'Низкие частоты': ('Bass', 'Graves'),
  'Средние частоты': ('Midrange', 'Medios'),
  'Высокие частоты': ('Treble', 'Agudos'),
  'Основной плеер': ('Main player', 'Reproductor principal'),
  'Сохранённые фоны': ('Saved backgrounds', 'Fondos guardados'),
  'Использовать фон плеера': (
    'Use player background',
    'Usar el fondo del reproductor'
  ),
  'Участок повтора': ('Loop range', 'Intervalo de repetición'),
  'до конца': ('end', 'final'),
  'Начало, секунды': ('Start, seconds', 'Inicio, segundos'),
  'Конец, секунды': ('End, seconds', 'Fin, segundos'),
  'До конца файла': ('Until the end of the file', 'Hasta el final del archivo'),
  'Укажите секунду в пределах видео.': (
    'Enter a time within the video.',
    'Introduce un tiempo dentro del vídeo.'
  ),
  'Конец должен быть после начала.': (
    'End time must follow the start.',
    'El final debe ser posterior al inicio.'
  ),
  'Всё видео': ('Entire video', 'Vídeo completo'),
  'Шрифты': ('Fonts', 'Fuentes'),
  'Импортировать шрифт': ('Import font', 'Importar fuente'),
  'Не удалось открыть файл оформления.': (
    'Could not open the appearance file.',
    'No se pudo abrir el archivo de apariencia.'
  ),
  'Обновления': ('Updates', 'Actualizaciones'),
  'Доступна новая версия {app}': (
    'A new version of {app} is available',
    'Hay una nueva versión de {app}'
  ),
  'Версия {version}': ('Version {version}', 'Versión {version}'),
  'Позже': ('Later', 'Más tarde'),
  'Открыть релиз на GitHub': (
    'Open release on GitHub',
    'Abrir versión en GitHub'
  ),
  'Установлена актуальная версия.': (
    'You have the latest version.',
    'Tienes la última versión.'
  ),
  'Не удалось проверить обновления.': (
    'Could not check for updates.',
    'No se pudieron comprobar las actualizaciones.'
  ),
  'Предлагать новые версии': (
    'Notify me about new versions',
    'Avisarme de nuevas versiones'
  ),
  'Проверяем…': ('Checking…', 'Comprobando…'),
  'Проверить обновления': ('Check for updates', 'Buscar actualizaciones'),
  'Главная': ('Home', 'Inicio'),
  'Поиск': ('Search', 'Buscar'),
  'Найти в чарте': (
    'Search for an artist or track',
    'Buscar artista o canción'
  ),
  'Очистить поиск': ('Clear search', 'Borrar búsqueda'),
  'Все жанры': ('All genres', 'Todos los géneros'),
  'Электроника': ('Electronic', 'Electrónica'),
  'Хип-хоп': ('Hip-hop', 'Hip hop'),
  'Рок': ('Rock', 'Rock'),
  'Поп': ('Pop', 'Pop'),
  'Топ треков': ('Top tracks', 'Top canciones'),
  'Воспроизвести подборку': ('Play chart', 'Reproducir la lista'),
  'Открыть живой виджет': (
    'Show widget instructions',
    'Ver instrucciones del widget'
  ),
  'Сверните приложение во время воспроизведения.': (
    'Leave the app while music is playing.',
    'Sal de la aplicación mientras suena la música.'
  ),
  'Медиатека': ('Library', 'Biblioteca'),
  'Избранное': ('Favorites', 'Favoritos'),
  'Добавить': ('Add', 'Añadir'),
  'Добавить музыку': ('Add music', 'Añadir música'),
  'Настройки': ('Settings', 'Ajustes'),
  'Оформление': ('Appearance', 'Apariencia'),
  'Язык': ('Language', 'Idioma'),
  'Горячие клавиши': ('Shortcuts', 'Atajos'),
  'Ваш профиль': ('Your profile', 'Tu perfil'),
  'Мой профиль': ('My profile', 'Mi perfil'),
  'Музыка под ваше настроение': (
    'Music for your mood',
    'Música para tu estado de ánimo'
  ),
  'Ваше пространство': ('Your space', 'Tu espacio'),
  'Профиль сохранён': ('Profile saved', 'Perfil guardado'),
  'Не удалось сохранить профиль.': (
    'Could not save the profile.',
    'No se pudo guardar el perfil.'
  ),
  'Аватар': ('Profile picture', 'Foto de perfil'),
  'Выбрать аватар': ('Choose profile picture', 'Elegir foto de perfil'),
  'Убрать аватар': ('Remove profile picture', 'Quitar foto de perfil'),
  'Имя': ('Name', 'Nombre'),
  'О себе или о своём настроении': (
    'About you or your mood',
    'Sobre ti o tu estado de ánimo'
  ),
  'Сохранить профиль': ('Save profile', 'Guardar perfil'),
  'ВАША МУЗЫКА. ВАШ РИТМ.': (
    'YOUR MUSIC. YOUR RHYTHM.',
    'TU MÚSICA. TU RITMO.'
  ),
  'СЕЙЧАС В ВАШЕМ ПРОСТРАНСТВЕ': ('NOW PLAYING', 'SONANDO AHORA'),
  'Добавьте музыку и найдите свой ритм': (
    'Add music to get started',
    'Añade música para empezar'
  ),
  'Моя музыка': ('My music', 'Mi música'),
  'YouTube / ссылка': ('YouTube / link', 'YouTube / enlace'),
  'Виджет': ('Widget', 'Widget'),
  'Настроение в один клик': ('Styles', 'Estilos'),
  'Настроить оформление': ('Customize appearance', 'Personalizar apariencia'),
  '4K-видеофон, шрифты и оформление виджета': (
    '4K video backgrounds, fonts and widget appearance',
    'Fondos de vídeo 4K, fuentes y apariencia del widget'
  ),
  'Плавающий виджет': ('Floating widget', 'Widget flotante'),
  'Открыть плавающий виджет': ('Open floating widget', 'Abrir widget flotante'),
  'Закрепить поверх окон': (
    'Keep above other windows',
    'Mantener sobre otras ventanas'
  ),
  'Настроить виджет': ('Customize widget', 'Personalizar widget'),
  'Развернуть плеер': (
    'Restore player window',
    'Restaurar ventana del reproductor'
  ),
  'Свернуть в панель задач': (
    'Minimize to taskbar',
    'Minimizar a la barra de tareas'
  ),
  'Полярное сияние': ('Northern lights', 'Aurora boreal'),
  'Холодный зелёный и мягкий свет': (
    'Cool green and soft light',
    'Verde frío y luz suave'
  ),
  'Неоновая ночь': ('Neon night', 'Noche de neón'),
  'Фиолетовый, индиго и неон': (
    'Violet, indigo and neon',
    'Violeta, índigo y neón'
  ),
  'Последний закат': ('Last sunset', 'Último atardecer'),
  'Тёплый оранжевый и винный': (
    'Warm orange and burgundy',
    'Naranja cálido y burdeos'
  ),
  'Северный лёд': ('Northern ice', 'Hielo del norte'),
  'Спокойные оттенки синего': (
    'Quiet shades of blue',
    'Tonos tranquilos de azul'
  ),
  'Сакура': ('Cherry blossom', 'Flor de cerezo'),
  'Розовый свет на тёмном фоне': (
    'Pink light on a dark background',
    'Luz rosa sobre fondo oscuro'
  ),
  'Тихий лес': ('Quiet forest', 'Bosque tranquilo'),
  'Мох, хвоя и глубокие тени': (
    'Moss, pine and deep shadows',
    'Musgo, pino y sombras profundas'
  ),
  'Тёплая плёнка': ('Warm film', 'Película cálida'),
  'Янтарь, кофе и вечерний свет': (
    'Amber, coffee and evening light',
    'Ámbar, café y luz del atardecer'
  ),
  'Графит': ('Graphite', 'Grafito'),
  'Сдержанный монохром': ('Muted monochrome', 'Monocromo discreto'),
  'Готовый стиль': ('Presets', 'Estilos predefinidos'),
  'Выберите настроение — оформление плеера и виджета изменится сразу.': (
    'Apply a style to the player and widget.',
    'Aplica un estilo al reproductor y al widget.'
  ),
  'Свой фон': ('Custom background', 'Fondo personalizado'),
  'Картинка или зацикленное видео. Исходный файл используется без повторного сжатия.':
      (
    'Use a picture or a looping video at its original quality.',
    'Usa una imagen o un vídeo en bucle con su calidad original.'
  ),
  'Изображения': ('Images', 'Imágenes'),
  'Видеофайлы': ('Video files', 'Archivos de vídeo'),
  'Готовый 4K-видеофон': ('Built-in 4K video', 'Vídeo 4K incluido'),
  'Импортировать своё видео': ('Import your video', 'Importar tu vídeo'),
  'Копируем видео…': ('Copying video…', 'Copiando vídeo…'),
  'Моё видео': ('My video', 'Mi vídeo'),
  'Не удалось импортировать видео. Проверьте файл и свободное место.': (
    'Could not import the video. Check the file and available disk space.',
    'No se pudo importar el vídeo. Comprueba el archivo y el espacio libre.'
  ),
  'Выбрать фото': ('Choose photo', 'Elegir foto'),
  'Вернуть готовый фон': (
    'Restore preset background',
    'Restaurar fondo predefinido'
  ),
  'Заполнить без искажения': ('Fill and crop', 'Rellenar y recortar'),
  'Показать целиком': ('Fit entire image', 'Mostrar imagen completa'),
  'Затемнение фона': ('Background dimming', 'Oscurecimiento del fondo'),
  'Размытие': ('Blur', 'Desenfoque'),
  'Выключено': ('Off', 'Desactivado'),
  'Живой фон': ('Animate background', 'Animar el fondo'),
  'Движение готовых тем': ('Animate presets', 'Animar estilos'),
  'Акцент и интерфейс': ('Accent and interface', 'Color de acento e interfaz'),
  'Цвет {hex}': ('Color {hex}', 'Color {hex}'),
  'Шрифт': ('Font', 'Fuente'),
  'Системный': ('System', 'Sistema'),
  'Плотность панелей': ('Panel opacity', 'Opacidad de paneles'),
  'Часы на главной': ('Show clock on Home', 'Mostrar reloj en Inicio'),
  'Та же музыка и тот же фон в компактном окне поверх других приложений.': (
    'Your music and background in a compact window above other apps.',
    'Tu música y tu fondo en una ventana compacta sobre otras aplicaciones.'
  ),
  'Стекло': ('Glass', 'Cristal'),
  'Матовый': ('Solid', 'Sólido'),
  'Минимум': ('Minimal', 'Minimalista'),
  'Ширина': ('Width', 'Ancho'),
  'Высота': ('Height', 'Alto'),
  'Скругление': ('Corner radius', 'Radio de las esquinas'),
  'Затемнение виджета': ('Widget dimming', 'Oscurecimiento del widget'),
  'Поверх остальных окон': ('Always on top', 'Siempre visible'),
  'Показывать исполнителя': ('Show artist', 'Mostrar artista'),
  'Показывать перемотку': ('Show seek bar', 'Mostrar barra de reproducción'),
  'Часы в виджете': ('Show clock in widget', 'Mostrar reloj en el widget'),
  'Сбросить оформление': ('Reset appearance', 'Restablecer apariencia'),
  'Фоновое изображение недоступно. Выберите файл в оформлении.': (
    'Background image unavailable. Choose a file in Appearance.',
    'Fondo no disponible. Elige un archivo en Apariencia.'
  ),
  'Видеофон недоступен. Выберите файл в оформлении.': (
    'Video background unavailable. Choose a file in Appearance.',
    'Fondo de vídeo no disponible. Elige un archivo en Apariencia.'
  ),
  'Позиция воспроизведения': ('Playback position', 'Posición de reproducción'),
  'Перемешать': ('Shuffle', 'Aleatorio'),
  'Предыдущий трек': ('Previous track', 'Pista anterior'),
  'Пауза': ('Pause', 'Pausar'),
  'Воспроизвести': ('Play', 'Reproducir'),
  'Следующий трек': ('Next track', 'Pista siguiente'),
  'Повтор выключен': ('Repeat off', 'Repetición desactivada'),
  'Повтор очереди': ('Repeat queue', 'Repetir cola'),
  'Повтор трека': ('Repeat track', 'Repetir pista'),
  'Выберите трек': ('Choose a track', 'Elige una pista'),
  'Громкость': ('Volume', 'Volumen'),
  'Без названия': ('Untitled', 'Sin título'),
  'Неизвестный исполнитель': ('Unknown artist', 'Artista desconocido'),
  'По ссылке': ('From link', 'Desde un enlace'),
  'Не удалось воспроизвести трек.': (
    'Could not play the track.',
    'No se pudo reproducir la pista.'
  ),
  'Не удалось восстановить настройки плеера.': (
    'Could not restore player settings.',
    'No se pudieron restaurar los ajustes del reproductor.'
  ),
  'Не удалось выполнить действие плеера.': (
    'Could not complete the player action.',
    'No se pudo completar la acción del reproductor.'
  ),
  'Путь к треку не указан': (
    'Track path is missing',
    'Falta la ruta de la pista'
  ),
  'Файл не найден. Добавьте музыку заново': (
    'File not found. Add the music again.',
    'Archivo no encontrado. Vuelve a añadir la música.'
  ),
  'Не удалось открыть виджет.': (
    'Could not open the widget.',
    'No se pudo abrir el widget.'
  ),
  'Не удалось развернуть плеер.': (
    'Could not restore the player window.',
    'No se pudo restaurar la ventana del reproductor.'
  ),
  'Открыть ссылку': ('Open link', 'Abrir enlace'),
  'Включить по ссылке': ('Play from a link', 'Reproducir desde un enlace'),
  'YouTube, Shorts или прямая ссылка на MP3, FLAC, M4A и другие аудиофайлы.': (
    'YouTube, Shorts or a direct link to an MP3, FLAC, M4A or other audio file.',
    'YouTube, Shorts o un enlace directo a un archivo MP3, FLAC, M4A u otro archivo de audio.'
  ),
  'Вставьте ссылку на трек…': (
    'Paste a track link…',
    'Pega un enlace a una pista…'
  ),
  'Открываем…': ('Opening…', 'Abriendo…'),
  'Воспроизвести ссылку': ('Play link', 'Reproducir enlace'),
  'Введите корректную ссылку HTTPS на YouTube или аудиофайл.': (
    'Enter a valid HTTPS link to YouTube or an audio file.',
    'Introduce un enlace HTTPS válido a YouTube o a un archivo de audio.'
  ),
  'Нужна ссылка на отдельный ролик YouTube или прямая ссылка на аудиофайл.': (
    'Use a link to one YouTube video or a direct audio link.',
    'Usa un enlace a un solo vídeo de YouTube o un enlace directo de audio.'
  ),
  'Не удалось открыть ссылку.': (
    'Could not open the link.',
    'No se pudo abrir el enlace.'
  ),
  'YouTube не отвечает. Проверьте подключение к интернету.': (
    'YouTube is not responding. Check your internet connection.',
    'YouTube no responde. Comprueba la conexión a Internet.'
  ),
  'Не удалось запустить YouTube.': (
    'Could not start YouTube.',
    'No se pudo iniciar YouTube.'
  ),
  'Для YouTube нужен Microsoft Edge WebView2 Runtime.': (
    'YouTube requires Microsoft Edge WebView2 Runtime.',
    'YouTube requiere Microsoft Edge WebView2 Runtime.'
  ),
  'Ошибка связи с YouTube.': (
    'YouTube connection error.',
    'Error de conexión con YouTube.'
  ),
  'Не удалось открыть страницу YouTube.': (
    'Could not open the YouTube page.',
    'No se pudo abrir la página de YouTube.'
  ),
  'Нажмите ▶ внутри видео, чтобы начать воспроизведение.': (
    'Press ▶ inside the video to start playback.',
    'Pulsa ▶ dentro del vídeo para iniciar la reproducción.'
  ),
  'Видео удалено, скрыто или недоступно.': (
    'The video is removed, private or unavailable.',
    'El vídeo se eliminó, es privado o no está disponible.'
  ),
  'YouTube запретил встраивание этого ролика.': (
    'YouTube blocked embedding for this video.',
    'YouTube ha bloqueado la inserción de este vídeo.'
  ),
  'YouTube не принял идентификатор приложения.': (
    'YouTube did not accept the app identity.',
    'YouTube no aceptó la identidad de la aplicación.'
  ),
  'Встроенный проигрыватель YouTube не смог открыть видео.': (
    'The embedded YouTube player could not open the video.',
    'El reproductor de YouTube integrado no pudo abrir el vídeo.'
  ),
  'YouTube не смог открыть видео.': (
    'YouTube could not open the video.',
    'YouTube no pudo abrir el vídeo.'
  ),
  'Не удалось открыть браузер': (
    'Could not open browser',
    'No se pudo abrir el navegador'
  ),
  'Страница YouTube': ('YouTube watch page', 'Página de YouTube'),
  'Открыть страницу YouTube здесь': (
    'Open YouTube page here',
    'Abrir página de YouTube aquí'
  ),
  'Открыть в браузере': ('Open in browser', 'Abrir en el navegador'),
  'Закрыть YouTube': ('Close YouTube', 'Cerrar YouTube'),
  'Выберите папку на ПК для сканирования аудиофайлов': (
    'Choose a folder to scan for audio files',
    'Elige una carpeta para buscar archivos de audio'
  ),
  'Сканируем папку…': ('Scanning folder…', 'Buscando en la carpeta…'),
  'Обработано треков: {count}': (
    'Tracks processed: {count}',
    'Pistas procesadas: {count}'
  ),
  'Не удалось отсканировать папку.': (
    'Could not scan the folder.',
    'No se pudo analizar la carpeta.'
  ),
  'Сканирование...': ('Scanning…', 'Buscando…'),
  'Выбрать папку': ('Choose folder', 'Elegir carpeta'),
  'Ваша медиатека пуста.\nПерейдите в раздел "Добавить", чтобы отсканировать музыку.':
      (
    'Your library is empty.\nUse Add to scan your music folders.',
    'Tu biblioteca está vacía.\nUsa Añadir para buscar música en tus carpetas.'
  ),
  'У вас пока нет любимых треков.\nНажмите на сердечко рядом с треком в Медиатеке, чтобы добавить его сюда.':
      (
    'No favorites yet.\nSelect the heart next to a track in your Library to add it here.',
    'Aún no hay favoritos.\nPulsa el corazón junto a una pista de tu Biblioteca para añadirla aquí.'
  ),
  'Поиск недоступен. Проверьте подключение и повторите запрос.': (
    'Search is unavailable. Check your connection and try again.',
    'La búsqueda no está disponible. Comprueba la conexión e inténtalo de nuevo.'
  ),
  'Поиск музыки — превью': (
    'Search music previews',
    'Buscar fragmentos de música'
  ),
  'Введите название трека или исполнителя...': (
    'Enter a track or artist…',
    'Introduce una pista o un artista…'
  ),
  'Ничего не найдено': ('No results', 'Sin resultados'),
  'Введите запрос и нажмите Enter или стрелочку': (
    'Enter a query and press Enter or the arrow',
    'Escribe una consulta y pulsa Intro o la flecha'
  ),
  'Воспроизведение / пауза': ('Play / pause', 'Reproducir / pausar'),
  'Выключить / включить звук': ('Mute / unmute', 'Silenciar / activar sonido'),
  'Переключить плавающий виджет': (
    'Toggle floating widget',
    'Alternar widget flotante'
  ),
  'Это сочетание уже занято. Выберите другое.': (
    'This shortcut is already in use. Choose another.',
    'Este atajo ya está en uso. Elige otro.'
  ),
  'Глобальные горячие клавиши доступны в Windows.': (
    'Global shortcuts are available on Windows.',
    'Los atajos globales están disponibles en Windows.'
  ),
  'Глобальные горячие клавиши': ('Global shortcuts', 'Atajos globales'),
  'Управляйте музыкой и виджетом из других приложений Windows. Для страницы YouTube используйте её кнопки.':
      (
    'Control music and the widget from other Windows apps. Use the controls on the YouTube watch page.',
    'Controla la música y el widget desde otras aplicaciones de Windows. Usa los controles de la página de YouTube.'
  ),
  'Сочетание занято': ('Shortcut is in use', 'Atajo en uso'),
  'Изменить': ('Change', 'Cambiar'),
  'Отмена': ('Cancel', 'Cancelar'),
  'Сохранить': ('Save', 'Guardar'),
  'Не удалось сохранить настройки.': (
    'Could not save settings.',
    'No se pudieron guardar los ajustes.'
  ),
};
