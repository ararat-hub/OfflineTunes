const additionalLanguages = <String, (String, String, String, String, String)>{
  'Главная': ('Головна', 'Strona główna', 'Início', 'Home', 'Ana sayfa'),
  'Поиск': ('Пошук', 'Szukaj', 'Pesquisar', 'Cerca', 'Ara'),
  'Медиатека': (
    'Медіатека',
    'Biblioteka',
    'Biblioteca',
    'Libreria',
    'Kitaplık'
  ),
  'Избранное': ('Вибране', 'Ulubione', 'Favoritos', 'Preferiti', 'Favoriler'),
  'Подборки': ('Добірки', 'Odkrywaj', 'Descobrir', 'Scopri', 'Keşfet'),
  'Рекомендации': (
    'Рекомендації',
    'Polecane',
    'Recomendações',
    'Consigli',
    'Öneriler'
  ),
  'Популярное': ('Популярне', 'Popularne', 'Em alta', 'Popolari', 'Popüler'),
  'Для вас': ('Для вас', 'Dla Ciebie', 'Para você', 'Per te', 'Sana özel'),
  'Часто слушаете': (
    'Часто слухаєте',
    'Często słuchane',
    'Mais ouvidas',
    'Più ascoltati',
    'Sık dinlenenler'
  ),
  'Все треки': (
    'Усі треки',
    'Wszystkie utwory',
    'Todas as faixas',
    'Tutti i brani',
    'Tüm parçalar'
  ),
  'Недавно прослушанные': (
    'Нещодавно прослухані',
    'Ostatnio odtwarzane',
    'Reproduzidas recentemente',
    'Riprodotti di recente',
    'Son dinlenenler'
  ),
  'В вашей медиатеке': (
    'У вашій медіатеці',
    'W Twojej bibliotece',
    'Na sua biblioteca',
    'Nella tua libreria',
    'Kitaplığında'
  ),
  'Ничего не найдено': (
    'Нічого не знайдено',
    'Nic nie znaleziono',
    'Nenhum resultado',
    'Nessun risultato',
    'Sonuç bulunamadı'
  ),
  'Каталог временно недоступен.': (
    'Каталог тимчасово недоступний.',
    'Katalog jest chwilowo niedostępny.',
    'O catálogo está temporariamente indisponível.',
    'Il catalogo è temporaneamente non disponibile.',
    'Katalog şu anda kullanılamıyor.'
  ),
  'Введите название трека или исполнителя...': (
    'Введіть назву треку або ім’я виконавця…',
    'Wpisz nazwę utworu lub wykonawcy…',
    'Digite o nome da faixa ou do artista…',
    'Inserisci il titolo o il nome dell’artista…',
    'Parça veya sanatçı adını yazın…'
  ),
  'Повторить': (
    'Повторити',
    'Spróbuj ponownie',
    'Tentar novamente',
    'Riprova',
    'Yeniden dene'
  ),
  'Ещё результаты': (
    'Інші результати',
    'Więcej wyników',
    'Mais resultados',
    'Altri risultati',
    'Daha fazla sonuç'
  ),
  'Записи из музыкальных каталогов': (
    'Записи з музичних каталогів',
    'Nagrania z katalogów muzycznych',
    'Gravações de catálogos musicais',
    'Brani dai cataloghi musicali',
    'Müzik kataloglarındaki kayıtlar'
  ),
  'Найденные треки': (
    'Знайдені треки',
    'Znalezione utwory',
    'Faixas encontradas',
    'Brani trovati',
    'Bulunan parçalar'
  ),
  'Подборка · Apple Music': (
    'Результати · Apple Music',
    'Wyniki · Apple Music',
    'Resultados · Apple Music',
    'Risultati · Apple Music',
    'Sonuçlar · Apple Music'
  ),
  'Доступно в oTune': (
    'Доступно в oTune',
    'Dostępne w oTune',
    'Disponível no oTune',
    'Disponibile in oTune',
    'oTune’da mevcut'
  ),
  'Найти в чарте': (
    'Шукати виконавця або трек',
    'Szukaj wykonawcy lub utworu',
    'Buscar artista ou faixa',
    'Cerca artista o brano',
    'Sanatçı veya parça ara'
  ),
  'Очистить поиск': (
    'Очистити пошук',
    'Wyczyść wyszukiwanie',
    'Limpar pesquisa',
    'Cancella ricerca',
    'Aramayı temizle'
  ),
  'Мир': ('Світ', 'Świat', 'Mundo', 'Mondo', 'Dünya'),
  'Россия': ('Росія', 'Rosja', 'Rússia', 'Russia', 'Rusya'),
  'Все жанры': (
    'Усі жанри',
    'Wszystkie gatunki',
    'Todos os gêneros',
    'Tutti i generi',
    'Tüm türler'
  ),
  'Электроника': (
    'Електроніка',
    'Elektronika',
    'Eletrônica',
    'Elettronica',
    'Elektronik'
  ),
  'Хип-хоп': ('Хіп-хоп', 'Hip-hop', 'Hip-hop', 'Hip-hop', 'Hip hop'),
  'Рок': ('Рок', 'Rock', 'Rock', 'Rock', 'Rock'),
  'Поп': ('Поп', 'Pop', 'Pop', 'Pop', 'Pop'),
  'Топ треков': (
    'Топ треків',
    'Najpopularniejsze utwory',
    'Faixas mais ouvidas',
    'Brani più ascoltati',
    'En popüler parçalar'
  ),
  'Топ треков в России': (
    'Топ треків у Росії',
    'Najpopularniejsze utwory w Rosji',
    'Mais ouvidas na Rússia',
    'Brani più ascoltati in Russia',
    'Rusya’da en popüler parçalar'
  ),
  'Популярные совпадения': (
    'Популярні збіги',
    'Popularne wyniki',
    'Resultados populares',
    'Risultati popolari',
    'Popüler sonuçlar'
  ),
  'По популярности · Deezer': (
    'За популярністю · Deezer',
    'Według popularności · Deezer',
    'Por popularidade · Deezer',
    'Per popolarità · Deezer',
    'Popülerliğe göre · Deezer'
  ),
  'Чарт · Apple Music': (
    'Чарт · Apple Music',
    'Lista przebojów · Apple Music',
    'Parada · Apple Music',
    'Classifica · Apple Music',
    'Liste · Apple Music'
  ),
  'По числу прослушиваний · Audius': (
    'За кількістю прослуховувань · Audius',
    'Według odtworzeń · Audius',
    'Por reproduções · Audius',
    'Per ascolti · Audius',
    'Dinlenme sayısına göre · Audius'
  ),
  'Сохранённая подборка · {provider}': (
    'Збережена добірка · {provider}',
    'Zapisana lista · {provider}',
    'Lista salva · {provider}',
    'Classifica salvata · {provider}',
    'Kayıtlı liste · {provider}'
  ),
  'Прослушиваний: {count}': (
    'Прослуховувань: {count}',
    'Odtworzenia: {count}',
    'Reproduções: {count}',
    'Ascolti: {count}',
    'Dinlenme: {count}'
  ),
  'Воспроизвести подборку': (
    'Відтворити добірку',
    'Odtwórz listę',
    'Reproduzir lista',
    'Riproduci classifica',
    'Listeyi çal'
  ),
  'Открыть в {provider}': (
    'Відкрити в {provider}',
    'Otwórz w {provider}',
    'Abrir no {provider}',
    'Apri in {provider}',
    '{provider} uygulamasında aç'
  ),
  'О треке': (
    'Про трек',
    'O utworze',
    'Sobre a faixa',
    'Informazioni sul brano',
    'Parça bilgileri'
  ),
  'Сейчас играет': (
    'Зараз грає',
    'Teraz odtwarzane',
    'Tocando agora',
    'In riproduzione',
    'Şu an çalıyor'
  ),
  'Воспроизвести': ('Відтворити', 'Odtwórz', 'Reproduzir', 'Riproduci', 'Çal'),
  'Пауза': ('Пауза', 'Wstrzymaj', 'Pausar', 'Pausa', 'Duraklat'),
  'Предыдущий трек': (
    'Попередній трек',
    'Poprzedni utwór',
    'Faixa anterior',
    'Brano precedente',
    'Önceki parça'
  ),
  'Следующий трек': (
    'Наступний трек',
    'Następny utwór',
    'Próxima faixa',
    'Brano successivo',
    'Sonraki parça'
  ),
  'Перемешать': (
    'Перемішати',
    'Odtwarzaj losowo',
    'Embaralhar',
    'Riproduzione casuale',
    'Karıştır'
  ),
  'Громкость': ('Гучність', 'Głośność', 'Volume', 'Volume', 'Ses düzeyi'),
  'В избранное': (
    'До вибраного',
    'Dodaj do ulubionych',
    'Adicionar aos favoritos',
    'Aggiungi ai preferiti',
    'Favorilere ekle'
  ),
  'Убрать из избранного': (
    'Вилучити з вибраного',
    'Usuń z ulubionych',
    'Remover dos favoritos',
    'Rimuovi dai preferiti',
    'Favorilerden çıkar'
  ),
  'Загрузки': (
    'Завантаження',
    'Pobrane',
    'Downloads',
    'Download',
    'İndirilenler'
  ),
  'Скачать': ('Завантажити', 'Pobierz', 'Baixar', 'Scarica', 'İndir'),
  'Скачано': ('Завантажено', 'Pobrano', 'Baixado', 'Scaricato', 'İndirildi'),
  'Скачивание': (
    'Завантаження',
    'Pobieranie',
    'Baixando',
    'Download in corso',
    'İndiriliyor'
  ),
  'Удалить загрузку': (
    'Видалити завантаження',
    'Usuń pobrany plik',
    'Remover download',
    'Rimuovi download',
    'İndirilen dosyayı sil'
  ),
  'Добавить музыку': (
    'Додати музику',
    'Dodaj muzykę',
    'Adicionar música',
    'Aggiungi musica',
    'Müzik ekle'
  ),
  'Добавить с устройства': (
    'Додати з пристрою',
    'Dodaj z urządzenia',
    'Adicionar do dispositivo',
    'Aggiungi dal dispositivo',
    'Cihazdan ekle'
  ),
  'Выбрать аудиофайлы': (
    'Вибрати аудіофайли',
    'Wybierz pliki audio',
    'Selecionar arquivos de áudio',
    'Scegli file audio',
    'Ses dosyalarını seç'
  ),
  'Включить по ссылке': (
    'Відтворити за посиланням',
    'Odtwórz z linku',
    'Reproduzir por link',
    'Riproduci da link',
    'Bağlantıdan çal'
  ),
  'Вставьте ссылку на трек…': (
    'Вставте посилання на трек…',
    'Wklej link do utworu…',
    'Cole o link da faixa…',
    'Incolla il link al brano…',
    'Parça bağlantısını yapıştırın…'
  ),
  'Воспроизвести ссылку': (
    'Відтворити за посиланням',
    'Odtwórz z linku',
    'Reproduzir link',
    'Riproduci link',
    'Bağlantıyı çal'
  ),
  'Не удалось открыть ссылку.': (
    'Не вдалося відкрити посилання.',
    'Nie udało się otworzyć linku.',
    'Não foi possível abrir o link.',
    'Impossibile aprire il link.',
    'Bağlantı açılamadı.'
  ),
  'Профиль': ('Профіль', 'Profil', 'Perfil', 'Profilo', 'Profil'),
  'Мой профиль': (
    'Мій профіль',
    'Mój profil',
    'Meu perfil',
    'Il mio profilo',
    'Profilim'
  ),
  'Ваш профиль': (
    'Ваш профіль',
    'Twój profil',
    'Seu perfil',
    'Il tuo profilo',
    'Profilin'
  ),
  'Ваше пространство': (
    'Ваш простір',
    'Twoja przestrzeń',
    'Seu espaço',
    'Il tuo spazio',
    'Alanınız'
  ),
  'Сохранить профиль': (
    'Зберегти профіль',
    'Zapisz profil',
    'Salvar perfil',
    'Salva profilo',
    'Profili kaydet'
  ),
  'Настройки': (
    'Налаштування',
    'Ustawienia',
    'Configurações',
    'Impostazioni',
    'Ayarlar'
  ),
  'Оформление': ('Оформлення', 'Wygląd', 'Aparência', 'Aspetto', 'Görünüm'),
  'Звук': ('Звук', 'Dźwięk', 'Som', 'Audio', 'Ses'),
  'Язык': ('Мова', 'Język', 'Idioma', 'Lingua', 'Dil'),
  'Язык интерфейса': (
    'Мова інтерфейсу',
    'Język interfejsu',
    'Idioma da interface',
    'Lingua dell’interfaccia',
    'Arayüz dili'
  ),
  'Найти язык': (
    'Знайти мову',
    'Znajdź język',
    'Buscar idioma',
    'Cerca una lingua',
    'Dil ara'
  ),
  'Дата и время': (
    'Дата й час',
    'Data i godzina',
    'Data e hora',
    'Data e ora',
    'Tarih ve saat'
  ),
  'Часовой пояс': (
    'Часовий пояс',
    'Strefa czasowa',
    'Fuso horário',
    'Fuso orario',
    'Saat dilimi'
  ),
  'Как на устройстве': (
    'Як на пристрої',
    'Zgodnie z urządzeniem',
    'Usar configuração do dispositivo',
    'Come sul dispositivo',
    'Cihaz ayarını kullan'
  ),
  'Найти часовой пояс': (
    'Знайти часовий пояс',
    'Znajdź strefę czasową',
    'Buscar fuso horário',
    'Cerca un fuso orario',
    'Saat dilimi ara'
  ),
  'Обновления': (
    'Оновлення',
    'Aktualizacje',
    'Atualizações',
    'Aggiornamenti',
    'Güncellemeler'
  ),
  'Проверить обновления': (
    'Перевірити оновлення',
    'Sprawdź aktualizacje',
    'Verificar atualizações',
    'Controlla aggiornamenti',
    'Güncellemeleri denetle'
  ),
  'Выбрать фото': (
    'Вибрати фото',
    'Wybierz zdjęcie',
    'Escolher foto',
    'Scegli foto',
    'Fotoğraf seç'
  ),
  'Свой фон': (
    'Власний фон',
    'Własne tło',
    'Fundo personalizado',
    'Sfondo personalizzato',
    'Özel arka plan'
  ),
  'Готовый стиль': (
    'Готовий стиль',
    'Gotowy styl',
    'Estilos prontos',
    'Stili predefiniti',
    'Hazır stiller'
  ),
  'Сохранённые фоны': (
    'Збережені фони',
    'Zapisane tła',
    'Fundos salvos',
    'Sfondi salvati',
    'Kayıtlı arka planlar'
  ),
  'Основной плеер': (
    'Основний плеєр',
    'Odtwarzacz główny',
    'Reprodutor principal',
    'Lettore principale',
    'Ana oynatıcı'
  ),
  'Виджет': ('Віджет', 'Widżet', 'Widget', 'Widget', 'Widget'),
  'Виджет плеера': (
    'Віджет плеєра',
    'Widżet odtwarzacza',
    'Widget do reprodutor',
    'Widget del lettore',
    'Oynatıcı widget’ı'
  ),
  'Импортировать своё видео': (
    'Імпортувати власне відео',
    'Importuj własne wideo',
    'Importar seu vídeo',
    'Importa il tuo video',
    'Kendi videonu içe aktar'
  ),
  'Шрифты': ('Шрифти', 'Czcionki', 'Fontes', 'Caratteri', 'Yazı tipleri'),
  'Карточка Android': (
    'Картка Android',
    'Karta multimediów Androida',
    'Cartão de mídia do Android',
    'Scheda multimediale Android',
    'Android medya kartı'
  ),
  'Отмена': ('Скасувати', 'Anuluj', 'Cancelar', 'Annulla', 'İptal'),
  'Закрыть': ('Закрити', 'Zamknij', 'Fechar', 'Chiudi', 'Kapat'),
  'Сохранить': ('Зберегти', 'Zapisz', 'Salvar', 'Salva', 'Kaydet'),
  'Удалить': ('Видалити', 'Usuń', 'Excluir', 'Elimina', 'Sil'),
  'Источник записи': (
    'Джерело запису',
    'Źródło nagrania',
    'Fonte da gravação',
    'Fonte della registrazione',
    'Kaydın kaynağı'
  ),
  'Моя музыка': (
    'Моя музика',
    'Moja muzyka',
    'Minha música',
    'La mia musica',
    'Müziğim'
  ),
  'Добавьте музыку и найдите свой ритм': (
    'Додайте музику й знайдіть свій ритм',
    'Dodaj muzykę i znajdź swój rytm',
    'Adicione músicas e encontre seu ritmo',
    'Aggiungi musica e trova il tuo ritmo',
    'Müzik ekle ve ritmini bul'
  ),
  'Музыка под ваше настроение': (
    'Музика під ваш настрій',
    'Muzyka na Twój nastrój',
    'Música para o seu humor',
    'Musica per il tuo umore',
    'Ruh haline uygun müzik'
  ),
};
