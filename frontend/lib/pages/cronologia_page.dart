import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/pages/upload_page.dart';
import 'package:frontend/utils.dart';
import '../api_client.dart';
import '../api_config.dart';
import '../auth_service.dart';
import 'package:frontend/categorypicker.dart';

import 'package:http/http.dart' as http;

import '../main.dart';
import 'detail_page.dart';
import 'info_page.dart';

const Color coloreSfondo = Color(0xFFF4F6F8);
const Color colorePrincipale = Color(0xFF7F5539);
const Color coloreAccento = Color(0xFFFF6B35);

class CronologiaScreen extends StatefulWidget {
  const CronologiaScreen({super.key});
  @override
  State<CronologiaScreen> createState() => _CronologiaScreenState();
}

class _CronologiaScreenState  extends State<CronologiaScreen>{
  bool _isLogin = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _skip = 0;
  final int _limit = 10;
  final List<Articolo> _articles = [];
  bool _isLoading = false;
  bool _hasMore = true;


  List<String> _categories = [];

  @override
  void initState(){
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkLoginStatus();
    _loadCategories();
    _loadArticles();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadArticles();
    }
  }
  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });
    try {
      String path = '/articles/me';
      final keyword = _searchController.text.trim();
      if (keyword.isNotEmpty) {
        path += '?keyword=${Uri.encodeComponent(keyword)}';
      }

      // Token, rinnovo anticipato ed eventuale nuovo tentativo: tutto in ApiClient.
      final response = await ApiClient.get(path);

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



  Future<void> _refreshArticles() async {
    setState(() {
      _articles.clear();
      _skip = 0;
      _hasMore = true;
    });
    await _loadArticles();
  }
  Future<void> _checkLoginStatus() async {
    if (mounted) {
      setState(() {
        _isLogin = AuthService.isLoggedIn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: coloreSfondo,
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
                await AuthService.logout();

                setState(() {
                  _isLogin=false;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyApp()),
                );
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
            _buildDrawerItem(Icons.home_outlined, 'Home Page', '',() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyApp()),
              );
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
            _buildDrawerItem(Icons.info_outline, 'Informazioni', 'Info Sistema',() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InformazioniScreen()),
              );
            },),
          ],
        ),
      ),

      body: RefreshIndicator(
        color: coloreAccento,
        backgroundColor: Colors.white,
        onRefresh: _refreshArticles,
        child: CustomScrollView(

          controller: _scrollController,
          slivers: [

            // --- App Bar Animata ---
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              backgroundColor: colorePrincipale,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 90.0),
                title: const Text(
                  'La tua Cronologia',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: colorePrincipale),
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(Icons.history, size: 150, color: coloreAccento.withAlpha(40)),
                    ),
                  ],
                ),
              ),

              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(70.0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cerca nei tuoi articoli...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.search, color: Colors.white),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
                          onPressed: () {
                            _searchController.clear();
                            _refreshArticles();
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      onSubmitted: (_) => _refreshArticles(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
            ),


            if (_articles.isEmpty && _isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: coloreAccento)),
              )
            else
            // 4. SliverPadding e SliverGrid sostituiscono il GridView.builder
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (index == _articles.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator(color: coloreAccento)),
                        );
                      }
                      return _buildTechCard(_articles[index]);
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

  Widget _buildTechCard(Articolo article) {
    final String title = article.title ;
    final String author = article.author ;
    final String description = article.description ;
    final String coverUrl = article.coverUrl ;
    final List<String> category = article.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: colorePrincipale.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ArticleDetailScreen(articleId: article.id)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: coloreSfondo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: coloreSfondo,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: coverUrl.isNotEmpty && !coverUrl.contains('placeholder')
                        ? Image.network(
                      '${ApiConfig.baseUrl}/articles/${article.id}/cover',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(category.isNotEmpty ? category.first : ''),
                    )
                        : _buildPlaceholderImage(category.isNotEmpty ? category.first : ''),
                  ),
                ),
                const SizedBox(width: 16),


                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colorePrincipale,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorePrincipale.withAlpha(180),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        author,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorePrincipale.withAlpha(180),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),


                Column(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 28,
                        color: coloreAccento,
                      ),
                      onPressed: () {
                        _mostraModificaDialog(article);
                        _searchController.clear();
                        _refreshArticles();
                      },
                    ),
                    const SizedBox(height: 18),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.restore_from_trash,
                        size: 28,
                        color: coloreAccento,
                      ),
                      onPressed: () {
                        _confermaEliminazione(article.id);
                        _searchController.clear();
                        _refreshArticles();
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Future<void> _confermaEliminazione(String articleId) async {
    bool? conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Elimina Articolo', style: TextStyle(color: colorePrincipale, fontWeight: FontWeight.bold)),
        content: const Text('Sei sicuro di voler eliminare definitivamente questo articolo? L\'azione eliminerà il file e i metadati. È irreversibile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla', style: TextStyle(color: colorePrincipale)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: coloreAccento),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (conferma == true) {
      setState(() => _isLoading = true);

      try {
        final response =
            await ApiClient.delete('/articles/$articleId/delete');

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Articolo eliminato con successo!'), backgroundColor: Colors.green),
            );
            _refreshArticles();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Errore durante l\'eliminazione: ${response.statusCode}'), backgroundColor: Colors.red),
            );
            await _refreshArticles();
          }
        }
      } catch (e) {
        debugPrint('Errore di connessione HTTP: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _mostraModificaDialog(Articolo article) async {
    final TextEditingController titleCtrl = TextEditingController(text: article.title);
    final TextEditingController authorCtrl = TextEditingController(text: article.author);
    final TextEditingController descCtrl = TextEditingController(text: article.description);
    final TextEditingController customCatCtrl = TextEditingController();
    final TextEditingController tagCtrl = TextEditingController();

    List<String> editCategories = List.from(article.category);
    List<String> editTags = List.from(article.tags);

    bool isCustomCategory = false;
    bool isSaving = false;
    bool? modificato = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Modifica Articolo', style: TextStyle(color: colorePrincipale, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(labelText: 'Titolo', prefixIcon: const Icon(Icons.title, color: colorePrincipale)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: authorCtrl,
                        decoration: InputDecoration(labelText: 'Autore', prefixIcon: const Icon(Icons.person, color: colorePrincipale)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: 'Descrizione', prefixIcon: const Icon(Icons.description, color: colorePrincipale)),
                      ),


                      const SizedBox(height: 24),
                      const Text('Categorie', style: TextStyle(fontWeight: FontWeight.bold, color: colorePrincipale)),
                      const SizedBox(height: 8),
                      if (editCategories.isNotEmpty)
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: editCategories.map((cat) => Chip(
                            label: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: coloreAccento,
                            deleteIconColor: Colors.white,
                            onDeleted: () => setDialogState(() => editCategories.remove(cat)),
                          )).toList(),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: isCustomCategory
                                ? TextField(
                              controller: customCatCtrl,
                              decoration: const InputDecoration(labelText: 'Scrivi e premi Invio', prefixIcon: Icon(Icons.edit, color: coloreAccento)),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty && !editCategories.contains(val.trim())) {
                                  setDialogState(() {
                                    editCategories.add(val.trim());
                                    customCatCtrl.clear();
                                    isCustomCategory = false;
                                  });
                                }
                              },
                            )
                                : InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () async {
                                final String? selected = await showCategoryPicker(
                                  context,
                                  categories: _categories,
                                  showAddCustomOption: true,
                                  title: 'Aggiungi una categoria',
                                );
                                if (selected == kCustomCategoryOption) {
                                  setDialogState(() => isCustomCategory = true);
                                } else if (selected != null && !editCategories.contains(selected)) {
                                  setDialogState(() => editCategories.add(selected));
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Aggiungi categoria', prefixIcon: Icon(Icons.category)),
                                child: const Text('Seleziona una categoria...', style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          ),
                          if (isCustomCategory)
                            IconButton(
                              icon: const Icon(Icons.close, color: colorePrincipale),
                              onPressed: () => setDialogState(() {
                                isCustomCategory = false;
                                customCatCtrl.clear();
                              }),
                            )
                        ],
                      ),
                      const SizedBox(height: 24),


                      const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold, color: colorePrincipale)),
                      const SizedBox(height: 8),
                      if (editTags.isNotEmpty)
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: editTags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: colorePrincipale.withAlpha(200),
                            deleteIconColor: Colors.white,
                            onDeleted: () => setDialogState(() => editTags.remove(tag)),
                          )).toList(),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tagCtrl,
                        decoration: const InputDecoration(labelText: 'Scrivi un tag e premi Invio', prefixIcon: Icon(Icons.local_offer)),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty && !editTags.contains(val.trim())) {
                            setDialogState(() {
                              editTags.add(val.trim());
                              tagCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context, false),
                  child: const Text('Annulla', style: TextStyle(color: colorePrincipale)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setDialogState(() => isSaving = true);
                    try {
                      Map<String, dynamic> updateData = {
                        "title": titleCtrl.text,
                        "author": authorCtrl.text,
                        "description": descCtrl.text,
                        "category": editCategories,
                        "tags": editTags,
                      };
                      final response = await ApiClient.put(
                        '/articles/${article.id}/update',
                        body: updateData,
                      );
                      if (response.statusCode == 200) {
                        if (context.mounted) Navigator.pop(context, true);
                      } else {
                        debugPrint("Errore modifica: ${response.body}");
                        setDialogState(() => isSaving = false);
                      }
                    } catch (e) {
                      debugPrint("Eccezione durante modifica: $e");
                      setDialogState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: coloreAccento),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Salva Modifiche', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
    if (modificato == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Articolo aggiornato con successo!'), backgroundColor: Colors.green),
      );
      await _refreshArticles();
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attenzione'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
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
}