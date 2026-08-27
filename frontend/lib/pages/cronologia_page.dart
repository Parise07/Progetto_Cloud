import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/pages/upload_page.dart';
import 'package:frontend/shared_preferences.dart';
import 'package:frontend/utils.dart';
import '../api_config.dart';

import 'package:http/http.dart' as http;

import 'detail_page.dart';

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

  @override
  void initState(){
    super.initState();
    _scrollController.addListener(_onScroll);
    checkLoginStatus(); // controlla che l'utente è già loggato
    _loadArticles();
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
      String url = '${ApiConfig.baseUrl}/articles/me';
      final keyword = _searchController.text.trim();
      if (keyword.isNotEmpty) {
        url += '?keyword=${Uri.encodeComponent(keyword)}';
      }

      // --- 1. RECUPERO IL TOKEN DALLA MEMORIA ---
      String? token = SharedPreferenceManager.instance.getString('access');

      // --- 2. AGGIUNGO L'HEADER DI AUTENTICAZIONE ---
      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

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


  Future<void> checkLoginStatus() async{
    String? accessToken = SharedPreferenceManager.instance.getString('access');
    if(accessToken == null){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: coloreSfondo,


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
    final String title = article.title ?? 'Senza titolo';
    final String author = article.author ?? 'Autore sconosciuto';
    final String coverUrl = article.coverUrl ?? '';
    final List<String> category = article.category ?? [];

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
                        article.description,
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
        String url = '${ApiConfig.baseUrl}/articles/$articleId';
        String? token = SharedPreferenceManager.instance.getString('access');

        final response = await http.delete(
          Uri.parse(url),
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );

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
          }
        }
      } catch (e) {
        debugPrint('Errore di connessione HTTP: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}
