import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/pages/cronologia_page.dart';
import 'package:frontend/pages/upload_page.dart';
import 'package:frontend/shared_preferences.dart';
import 'package:frontend/utils.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'pages/detail_page.dart';
import 'pages/info_page.dart';
import 'pages/login_page.dart';
import 'package:frontend/categorypicker.dart';
import 'package:http/http.dart' as http;


// Colori globali dell'applicazione
const Color coloreSfondo = Color(0xFFF4F6F8);
const Color colorePrincipale = Color(0xFF7F5539);
const Color coloreAccento = Color(0xFFFF6B35);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //inizializzo il database locale prima di tutto
  await SharedPreferenceManager.init();
  //allineo lo stato della sessione ai token eventualmente gia' salvati
  AuthService.init();
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

  String? _ragAnswer;

  final List<Articolo> _articles = [];

  // Lista categorie caricata dal backend (container "categories"),
  // così l'elenco resta sempre aggiornato con le categorie realmente esistenti
  // senza doverle ricercare/ricostruire scansionando tutti gli articoli.
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkLoginStatus();
    _loadCategories();
    _loadArticles(); // Caricamento iniziale
  }

  /// Recupera l'elenco di tutte le categorie disponibili da GET /categories
  Future<void> _loadCategories() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/articles/categories'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['categories'] ?? [];
        setState(() {
          _categories = items.map((e) => e.toString()).toList();
        });
      } else {
        debugPrint('Errore caricamento categorie: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore di connessione HTTP durante il caricamento categorie: $e');
    }
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
    setState(() {
      // Conta la validita' del refresh token, non la presenza dell'access:
      // un access scaduto viene rinnovato senza disturbare l'utente.
      _isLogin = AuthService.isLoggedIn;
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
      String path = '/articles?skip=$_skip&limit=$_limit';
      if (_selectedCategory != 'Tutte') {
        path += '&category=$_selectedCategory';
      }
      // Elenco pubblico: nessun token da allegare.
      final response = await ApiClient.get(path, autenticata: false);
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

    // La ricerca RAG e' protetta lato server: senza account la richiesta
    // verrebbe rifiutata con 401, quindi fermiamoci prima di inviarla.
    if (_isRagMode && !_isLogin) {
      showErrorDialog(
          "Per poter utilizzare la ricerca RAG hai bisogno di un account. Accedi o registrati .");
      return;
    }

    setState(() {
      _isLoading = true;
      _articles.clear();
    });
    String path = _isRagMode ? '/search/rag' : '/search/generic';

    try{
      final Map<String, dynamic> requestBody = _isRagMode
          ? {'question': query.trim()}
          :  {'keyword': query.trim()};
      // La ricerca generica e' pubblica, quella RAG richiede l'autenticazione:
      // il token e l'eventuale rinnovo li gestisce ApiClient.
      final response = await ApiClient.post(
        path,
        body: requestBody,
        autenticata: _isRagMode,
      );
      if (response.statusCode == 200){
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          if(_isRagMode){
            _ragAnswer = responseData['answer'] ?? "Nessuna risposta.";
            final List<dynamic> relevant_chunk = responseData['relevant_chunks'] ?? [];
            _articles.addAll(relevant_chunk.map((item) =>
                Articolo.fromJson(item as Map<String, dynamic>)).toList());
            _hasMore = false;
            _isLoading = false;
          }else{
            _ragAnswer=null;
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
              // seleziona categoria: apre il pannello con sezioni alfabetiche sticky
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final String? selected = await showCategoryPicker(
                    context,
                    categories: _categories,
                    showAllOption: true,
                  );
                  if (selected != null && selected != _selectedCategory) {
                    setState(() {
                      _selectedCategory = selected;
                    });
                    _refreshArticles();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCategory,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
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
                        setState(() {
                          _ragAnswer = null;
                        });
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
                  activeTrackColor: coloreAccento,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white.withAlpha(30),
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],
        ),
        actions: [
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

            if (_isLogin)
              _buildDrawerItem(Icons.logout, 'Log-out', 'Esci dall\'account', () async {
                // Revoca il refresh token su Keycloak, poi pulisce la sessione.
                await AuthService.logout();

                setState(() {
                  _isLogin=false;
                  _refreshArticles();
                });
              })
            else
              _buildDrawerItem(Icons.login, 'Log-in', 'Accedi con Keycloak', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) {
                  _checkLoginStatus();
                });
              }),
            const Divider(),
            _buildDrawerItem(Icons.history, 'Cronologia', 'Articoli visti di recente',() {
              if (_isLogin) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CronologiaScreen()),
                );
              } else{
                showErrorDialog("É necessario il login per poter visualizzare la cronologia. Accedi o registrati. ");
              }
            },),
            _buildDrawerItem(Icons.upload_file, 'Upload articolo', 'Carica file (PDF, TXT)',() {
              if(_isLogin){
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const  UploadScreen()),
                );}else{
                showErrorDialog("É necessario il login per poter caricare un articolo. Accedi o registrati");
              }
            },),
            _buildDrawerItem(Icons.info_outline, 'Informazioni', 'Info sistema',() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InformazioniScreen()),
              );
            },),
            /// _buildDrawerItem(Icons.psychology_outlined, 'RAG', 'Risposte del sistema RAG',() {
            ///   Navigator.push(
            ///     context,
            ///     MaterialPageRoute(builder: (context) => const  UploadScreen()),
            ///   );
            /// },),
          ],
        ),
      ),



      body: RefreshIndicator(
        color: coloreAccento,
        backgroundColor: Colors.white,
        onRefresh: _refreshArticles,
        child: _articles.isEmpty && _isLoading
            ? const Center(child: CircularProgressIndicator(color: coloreAccento))
        // Un unico CustomScrollView: risposta RAG, intestazione e griglia sono
        // slivers dello stesso scroll, quindi scorrono insieme invece di avere
        // la risposta fissa in testa con le card che le passano sotto.
            : CustomScrollView(
          controller: _scrollController,
          // Consente il pull-to-refresh anche quando il contenuto non riempie
          // lo schermo.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            if (_ragAnswer != null)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: coloreAccento.withAlpha(50), width: 2),
                    boxShadow: [
                      BoxShadow(color: coloreAccento.withAlpha(20), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology, color: coloreAccento, size: 28),
                          SizedBox(width: 10),
                          Text("Risposta dell'Assistente", style: TextStyle(fontWeight: FontWeight.bold, color: coloreAccento, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _ragAnswer!,
                        style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            if (_ragAnswer != null && _articles.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, 16, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Articoli Consultati",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorePrincipale),
                    ),
                  ),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _articles.length) {
                      return const Center(child: CircularProgressIndicator(color: coloreAccento));
                    }
                    return _buildArticleCard(_articles[index]);
                  },
                  childCount: _articles.length + (_hasMore ? 1 : 0),
                ),
              ),
            ),
          ],
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
                flex: 4,
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
                          spacing: 6.0,
                          runSpacing: 2.0,
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

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Errore'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

}