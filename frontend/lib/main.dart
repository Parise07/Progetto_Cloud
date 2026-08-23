import 'package:flutter/material.dart';

// ==========================================================================
// Colori globali dell'applicazione
// ==========================================================================
/// Colore principale — Navy scuro, elegante e autorevole per un'app di notizie.
/// Utilizzato per AppBar, Drawer header e accenti primari.
const Color colorePrincipale = Color(0xFF1B1B1B);

/// Colore secondario — Ambra dorata, calda e raffinata.
/// Utilizzato per il contenitore degli strumenti nell'AppBar e accenti secondari.
const Color coloreSecondario = Color(0xFF9B111E);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewsArchive RAG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorePrincipale,
          brightness: Brightness.light,
          primary: colorePrincipale,
          secondary: coloreSecondario,
          onPrimary: Colors.white,
          onSecondary: colorePrincipale,
          primaryContainer: colorePrincipale.withAlpha(30),
          secondaryContainer: coloreSecondario.withAlpha(60),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: colorePrincipale,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: Colors.black54,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const MyHomePage(title: 'NewsArchive'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // --- Stato della pagina ---
  bool _isRagMode = false;
  String _selectedCategory = 'Tutte';
  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 10;

  // Lista articoli caricati (mock per ora, predisposta per API)
  final List<Map<String, dynamic>> _articles = [];

  // Categorie disponibili per il filtro dropdown
  final List<String> _categories = [
    'Tutte',
    'Politica',
    'Economia',
    'Tecnologia',
    'Sport',
    'Cultura',
    'Scienza',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadArticles(); // Caricamento iniziale
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Listener per l'Infinite Scroll: quando l'utente si avvicina al fondo
  /// della lista, viene triggerato il caricamento della pagina successiva.
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadArticles();
    }
  }

  /// Carica gli articoli (mock). In produzione, questa funzione invocherà
  /// GET /articles?skip=_skip&limit=_limit&category=...
  Future<void> _loadArticles() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // --- TODO: Sostituire con chiamata HTTP reale ---
    // final response = await http.get(Uri.parse(
    //   '$baseUrl/articles?skip=$_skip&limit=$_limit'
    //   '${_selectedCategory != 'Tutte' ? '&category=$_selectedCategory' : ''}'
    // ));
    // final data = jsonDecode(response.body);
    // final List<Map<String, dynamic>> newArticles =
    //     List<Map<String, dynamic>>.from(data['articles']);

    // Simulazione di dati mock per la UI
    await Future.delayed(const Duration(milliseconds: 800));
    final List<Map<String, dynamic>> newArticles = List.generate(
      _limit,
      (index) => {
        'id': 'article-${_skip + index}',
        'title': 'Articolo di esempio #${_skip + index + 1}',
        'author': 'Autore ${_skip + index + 1}',
        'category': _categories[(_skip + index) % (_categories.length - 1) + 1],
        'cover_url': '', // Placeholder: nessuna immagine di copertina
        'uploaded_at': DateTime.now()
            .subtract(Duration(days: _skip + index))
            .toIso8601String(),
      },
    );
    // --- FINE Mock ---

    setState(() {
      _articles.addAll(newArticles);
      _skip += newArticles.length;
      _hasMore = newArticles.length == _limit;
      _isLoading = false;
    });
  }

  /// Resetta la lista e ricarica da zero (es. dopo cambio filtro o ricerca)
  Future<void> _refreshArticles() async {
    setState(() {
      _articles.clear();
      _skip = 0;
      _hasMore = true;
    });
    await _loadArticles();
  }

  /// Esegue la ricerca. In modalità RAG invoca POST /search/rag,
  /// altrimenti POST /search/generic.
  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    // TODO: Implementare la chiamata API di ricerca
    // if (_isRagMode) {
    //   POST /search/rag { "question": query }
    // } else {
    //   POST /search/generic { "keyword": query }
    // }

    debugPrint('Ricerca ${_isRagMode ? "RAG" : "Keyword"}: $query');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,

      // ===================================================================
      // APP BAR: Titolo | Filtro Dropdown | Barra di Ricerca | Switch RAG
      // ===================================================================
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 6,
        shadowColor: Colors.black54,
        title: Row(
          children: [
            // --- Titolo a sinistra ---
            const Text(
              'NewsArchive',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 24),

            // =============================================================
            // Contenitore unico con sfondo coloreSecondario e bordi
            // arrotondati: raggruppa Filtri + Ricerca + Switch RAG/Normal
            // =============================================================
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: coloreSecondario,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Dropdown Filtro Categorie ---
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        icon: Icon(
                          Icons.filter_list,
                          color: colorePrincipale.withAlpha(200),
                          size: 20,
                        ),
                        dropdownColor: coloreSecondario,
                        style: const TextStyle(
                          fontSize: 14,
                          color: colorePrincipale,
                          fontWeight: FontWeight.w500,
                        ),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                            _refreshArticles();
                          }
                        },
                      ),
                    ),

                    // --- Separatore verticale ---
                    Container(
                      height: 24,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: colorePrincipale.withAlpha(60),
                    ),

                    // --- Barra di Ricerca ---
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cerca articoli...',
                          hintStyle: TextStyle(
                            color: colorePrincipale.withAlpha(120),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: colorePrincipale.withAlpha(180),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: colorePrincipale.withAlpha(180),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _refreshArticles();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withAlpha(150),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 16,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: colorePrincipale,
                        ),
                        onSubmitted: _performSearch,
                        onChanged: (value) {
                          setState(() {}); // Aggiorna icona clear
                        },
                      ),
                    ),

                    // --- Separatore verticale ---
                    Container(
                      height: 24,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: colorePrincipale.withAlpha(60),
                    ),

                    // --- Switch RAG / Normal (label DOPO lo switch) ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _isRagMode,
                          onChanged: (bool value) {
                            setState(() {
                              _isRagMode = value;
                            });
                          },
                          activeColor: colorePrincipale,
                          activeTrackColor: colorePrincipale.withAlpha(100),
                          inactiveThumbColor: colorePrincipale.withAlpha(150),
                          inactiveTrackColor: colorePrincipale.withAlpha(40),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isRagMode ? 'RAG' : 'Normal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorePrincipale.withAlpha(220),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        actions: [
          // --- Icona Hamburger per aprire il Drawer (a destra) ---
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Menu',
            onPressed: () {
              scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),

      // ===================================================================
      // DRAWER LATERALE (a destra): Login, Cronologia, Update, Info
      // ===================================================================
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: colorePrincipale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.newspaper,
                    size: 48,
                    color: coloreSecondario,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'NewsArchive RAG',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Sistema di Archiviazione Notizie',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(179),
                    ),
                  ),
                ],
              ),
            ),

            // Log-in
            ListTile(
              leading: const Icon(Icons.login, color: colorePrincipale),
              title: const Text('Log-in'),
              subtitle: const Text('Accedi con il tuo account'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigazione verso schermata di login (Keycloak)
                debugPrint('Navigazione: Log-in');
              },
            ),
            const Divider(),

            // Cronologia articoli
            ListTile(
              leading: const Icon(Icons.history, color: colorePrincipale),
              title: const Text('Cronologia articoli'),
              subtitle: const Text('Articoli visualizzati di recente'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigazione verso cronologia
                debugPrint('Navigazione: Cronologia');
              },
            ),

            // Update articolo
            ListTile(
              leading: const Icon(Icons.upload_file, color: colorePrincipale),
              title: const Text('Upload articolo'),
              subtitle: const Text('Carica un nuovo articolo'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigazione verso upload_screen.dart
                debugPrint('Navigazione: Upload articolo');
              },
            ),

            // Informazioni
            ListTile(
              leading: const Icon(Icons.info_outline, color: colorePrincipale),
              title: const Text('Informazioni'),
              subtitle: const Text('Info sul sistema e versione'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'NewsArchive RAG',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 Progetto Cloud',
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Sistema RAG per l\'Archiviazione e '
                        'Ricerca di Notizie basato su Azure.',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),

      // ===================================================================
      // BODY: Infinite Scroll con GridView.builder di Card articolo
      // ===================================================================
      body: RefreshIndicator(
        color: coloreSecondario,
        backgroundColor: colorePrincipale,
        onRefresh: _refreshArticles,
        child: _articles.isEmpty && _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: coloreSecondario,
                  backgroundColor: colorePrincipale.withAlpha(30),
                ),
              )
            : _articles.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: colorePrincipale.withAlpha(77),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun articolo trovato',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorePrincipale.withAlpha(153),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GridView.builder(
                      controller: _scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 0.80,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      // +1 per il loader in fondo alla lista
                      itemCount: _articles.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Loader di paginazione (ultimo elemento)
                        if (index == _articles.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: coloreSecondario,
                                backgroundColor: colorePrincipale.withAlpha(30),
                              ),
                            ),
                          );
                        }
                        return _buildArticleCard(_articles[index]);
                      },
                    ),
                  ),
      ),
    );
  }

  /// Costruisce una singola Card per un articolo.
  /// Layout: Immagine di copertina (cover_url) in alto, sotto titolo e autore.
  Widget _buildArticleCard(Map<String, dynamic> article) {
    final String title = article['title'] ?? 'Senza titolo';
    final String author = article['author'] ?? 'Autore sconosciuto';
    final String coverUrl = article['cover_url'] ?? '';
    final String category = article['category'] ?? '';

    return Card(
      elevation: 3,
      shadowColor: colorePrincipale.withAlpha(40),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigazione verso article_detail_screen.dart
          // Navigator.push(context, MaterialPageRoute(
          //   builder: (_) => ArticleDetailScreen(articleId: article['id']),
          // ));
          debugPrint('Apri dettaglio articolo: ${article['id']}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Immagine di copertina (cover_url) ---
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorePrincipale.withAlpha(15),
                ),
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        // Gestione errore di caricamento immagine
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(category);
                        },
                      )
                    : _buildPlaceholderImage(category),
              ),
            ),

            // --- Sezione descrittiva: Titolo + Autore ---
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge categoria
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: coloreSecondario.withAlpha(60),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorePrincipale,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),

                    // Titolo dell'articolo
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          color: colorePrincipale,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Autore
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: colorePrincipale.withAlpha(130),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            author,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorePrincipale.withAlpha(130),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder per quando l'immagine di copertina non è disponibile.
  /// Mostra un'icona in base alla categoria dell'articolo.
  Widget _buildPlaceholderImage(String category) {
    IconData icon;
    switch (category) {
      case 'Politica':
        icon = Icons.account_balance;
        break;
      case 'Economia':
        icon = Icons.trending_up;
        break;
      case 'Tecnologia':
        icon = Icons.computer;
        break;
      case 'Sport':
        icon = Icons.sports_soccer;
        break;
      case 'Cultura':
        icon = Icons.palette;
        break;
      case 'Scienza':
        icon = Icons.science;
        break;
      default:
        icon = Icons.article;
    }

    return Center(
      child: Icon(
        icon,
        size: 48,
        color: coloreSecondario.withAlpha(100),
      ),
    );
  }
}
