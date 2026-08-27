import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/pages/cronologia_page.dart';
import 'package:frontend/pages/upload_page.dart';
import 'package:frontend/shared_preferences.dart';
import 'package:frontend/utils.dart';

import 'api_config.dart';
import 'pages/detail_page.dart';
import 'pages/info_page.dart';
import 'pages/login_page.dart';
import 'package:http/http.dart' as http;


// Colori globali dell'applicazione

/// 60% - Sfondo: Grigio chiarissimo elegante. Fa risaltare le card bianche.
const Color coloreSfondo = Color(0xFFF4F6F8);

/// 30% - Struttura: Navy scuro. Per AppBar, Testi, Drawer e icone principali.
const Color colorePrincipale = Color(0xFF7F5539);

/// 10% - Accento: Rosso Rubino. Usato SOLO per Call to Action, Switch attivi, Loader.
const Color coloreAccento = Color(0xFFFF6B35);

Future<void> main() async {
  // mi assicuro che flutter sia pronto prima di eseguire del codice
  WidgetsFlutterBinding.ensureInitialized();

  //inizializzo il database locale prima di tutto
  await SharedPreferenceManager.init();
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
        scaffoldBackgroundColor: coloreSfondo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorePrincipale,
          brightness: Brightness.light,
          primary: colorePrincipale,
          secondary: coloreAccento,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: colorePrincipale,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black26,
        ),
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
  bool _isLogin = false;
  // --- Stato della pagina ---
  bool _isRagMode = false;
  String _selectedCategory = 'Tutte';
  bool _isLoading = false;
  bool _hasMore = true;
  int _skip = 0;
  final int _limit = 10;

  // Lista articoli caricati (mock per ora, predisposta per API)
  final List<Articolo> _articles = [];

  // Categorie disponibili per il filtro dropdown
  final List<String> _categories = [
    'Tutte',
    'Politica',
    'Economia',
    'Tecnologia',
    'Sport',
    'Cultura',
    'Scienza',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkLoginStatus();
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

  Future<void> _checkLoginStatus() async{
    String? accessToken = SharedPreferenceManager.instance.getString('access');
     setState(() {
       _isLogin= accessToken != null;
     });
  }

  /// Carica gli articoli (mock). In produzione, questa funzione invocherà
  /// GET /articles?skip=_skip&limit=_limit&category=...
  Future<void> _loadArticles() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });
    try {
      String url = '${ApiConfig.baseUrl}/articles?skip=$_skip&limit=$_limit';
      if (_selectedCategory != 'Tutte') {
        url += '&category=$_selectedCategory';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['articles'] ?? [];
        setState(() {
          _articles.addAll(
              items.map((item) => Articolo.fromJson(item)).toList());
          _skip += items.length;
          _hasMore = items.length == _limit;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          debugPrint('Errore caricamento articoli: ${response.statusCode}');
        });
      }
      } catch (e) {
        setState(() {
          _isLoading=false;
          debugPrint('Errore di connessione HTTP: $e');
        });
    }

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
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _articles.clear();
    });
    String url = _isRagMode
        ? '${ApiConfig.baseUrl}/search/rag'
        : '${ApiConfig.baseUrl}/search/generic';

    try{
        final Map<String, dynamic> requestBody = _isRagMode
        ? {'question': query.trim()}
        :  {'keyword': query.trim()};
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );
        if (response.statusCode == 200){
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          setState(() {
            if(_isRagMode){
              final String aiAnswer = responseData['answer'] ?? "Nessuna risposta.";
              final List<dynamic> relevant_chunk =responseData['relevant_chunks'] ?? [];

              //TODO portarlo nella Rag page per visualizzare le conversazioni
              debugPrint('Risposta RAG');
              _isLoading=false;
            }else{
              final String corrispondenze = responseData['message'] ?? "Nessuna corrispondenza trovata";
              final List<dynamic> results= responseData ['results'] ?? [];
              _articles.addAll(results.map((item) => Articolo.fromJson(item as Map<String, dynamic>)).toList());
              _hasMore = false;
              _isLoading = false;
            }
          });
        }else{
          setState(() {
            _isLoading = false;
          });
          print('Errore nel recupero dei prodotti: ${response.statusCode}');
        }
    }catch(e){
      setState(() {
        _isLoading = false;
      });
      debugPrint('Errore di connessione HTTP: $e');
    }
    debugPrint('Ricerca ${_isRagMode ? "RAG" : "Keyword"}: $query');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,

      // APP BAR

      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            // --- Titolo a sinistra ---
            const Text(
              'NewsArchive',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 48),

            // container ricerca switch e categorie
            Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  // seleziona categoria
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white70,
                          size: 20,
                        ),
                        dropdownColor: colorePrincipale,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
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
                ),
                const SizedBox(width: 16),
                Expanded(
                    child:Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),

                      //barra di ricerca
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cerca articoli...',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: Colors.white70,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _refreshArticles();
                                  },
                                )
                              : null,
                          border:InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        ),
                        onSubmitted: _performSearch,
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                ),
                const SizedBox(width: 32),
              // --- Switch RAG / Normal (label DOPO lo switch) ---
            Row(
              children: [
                Text(
                  'RAG',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isRagMode ? Colors.white : Colors.white54,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isRagMode,
                  onChanged: (bool value) => setState(() => _isRagMode = value),
                  activeColor: Colors.white,
                  activeTrackColor: coloreAccento, // Il tocco di rosso per l'IA!
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white.withAlpha(30),
                ),
              ],
            ),
            const SizedBox(width: 16),
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


      // Menù a tendina Laterale
      endDrawer: Drawer(
        backgroundColor: coloreSfondo,
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
                    color: coloreAccento,
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

            // Log-in o log-out
            if (_isLogin)
            // Se è loggato, mostra LOG-OUT
              _buildDrawerItem(Icons.logout, 'Log-out', 'Esci dall\'account', () async {
                // Svuota la memoria locale (elimina il token JWT)
                await SharedPreferenceManager.clear();

                // Opzionale: torna al Login distruggendo tutto lo stack di pagine
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                  );
                }
              })
            else
            // Se NON è loggato, mostra LOG-IN
              _buildDrawerItem(Icons.login, 'Log-in', 'Accedi con Keycloak', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) {
                  // Quando l'utente torna indietro dal Login, ricontrolla lo stato!
                  _checkLoginStatus();
                });
              }),
            const Divider(),
            _buildDrawerItem(Icons.history, 'Cronologia', 'Articoli visti di recente',() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CronologiaScreen()),
              );
            },),
            _buildDrawerItem(Icons.upload_file, 'Upload articolo', 'Carica file (PDF, TXT)',() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const  UploadScreen()),
              );
            },),
            _buildDrawerItem(Icons.info_outline, 'Informazioni', 'Info sistema',() {
            Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InformazioniScreen()),
            );
            },),
            _buildDrawerItem(Icons.psychology_outlined, 'RAG', 'Risposte del sistema RAG',() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const  UploadScreen()), // todo portarlo in RAG page
              );
            },),
          ],
        ),
      ),


      // BODY: Infinite Scroll con GridView.builder di Card articolo

      body: RefreshIndicator(
        color: coloreAccento,
        backgroundColor: Colors.white,
        onRefresh: _refreshArticles,
        child: _articles.isEmpty && _isLoading
            ? const Center(child: CircularProgressIndicator(color: coloreAccento))
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: GridView.builder(
            controller: _scrollController,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.85,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: _articles.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _articles.length) {
                return const Center(child: CircularProgressIndicator(color: coloreAccento));
              }
              return _buildArticleCard(_articles[index]);
            },
          ),
        ),
      ),
    );
  }


  Widget _buildDrawerItem(IconData icon, String title, String subtitle, VoidCallback onTapAction) {
    return ListTile(
      leading: Icon(icon, color: colorePrincipale),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTapAction();
      },
    );
  }

  /// Costruisce una singola Card per un articolo.
  /// Layout: Immagine di copertina (cover_url) in alto, sotto titolo e autore.
  Widget _buildArticleCard(Articolo article) {
    final String title = article.title ?? 'Senza titolo';
    final String author = article.author ?? 'Autore sconosciuto';
    final String coverUrl = article.coverUrl?? '';
    final List<String> category = article.category ?? [] ;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorePrincipale.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ArticleDetailScreen(articleId: article.id ,)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Immagine card
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  color: coloreSfondo, // Sfondo per il placeholder
                  child: coverUrl.isNotEmpty && !coverUrl.contains('placeholder')
                      ? Image.network(
                    '${ApiConfig.baseUrl}/articles/${article.id}/cover',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(category.isNotEmpty ? category.first : ''),
                  )
                      : _buildPlaceholderImage(category.isNotEmpty ? category.first : ''),
                ),
              ),

              // Dettagli
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lista di categorie
                      if (category.isNotEmpty)
                        Wrap(
                          spacing: 6.0, // spazio orizzontale tra i badge
                          runSpacing: 4.0, // spazio verticale se vanno a capo
                          children: category.map((c) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: coloreAccento.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: coloreAccento,
                                  letterSpacing: 0.5
                              ),
                            ),
                          )).toList(),
                        ),
                      const Spacer(),

                      // Titolo
                      Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, color: colorePrincipale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Autore
                      Row(
                        children: [
                          const Icon(Icons.edit_document, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              author,
                              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
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
      ),
    );
  }

  /// Visualizzazione immagine se non è stata caricata
  Widget _buildPlaceholderImage(String category) {
    IconData icon;
    switch (category.toLowerCase()) {
      case 'politica': icon = Icons.account_balance; break;
      case 'economia': icon = Icons.trending_up; break;
      case 'ecnologia': icon = Icons.memory; break;
      case 'sport': icon = Icons.sports_soccer; break;
      case 'cultura': icon = Icons.palette; break;
      case 'scienza': icon = Icons.biotech; break;
      default: icon = Icons.article_outlined;
    }
    return Center(
      child: Icon(icon, size: 56, color: colorePrincipale.withAlpha(50)),
    );
  }
}
