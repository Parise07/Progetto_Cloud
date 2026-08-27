import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../api_config.dart';
import '../shared_preferences.dart';
import "package:pdf/widgets.dart" as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils.dart';



// --- COLORI DESIGN SYSTEM 60-30-10 ---
const Color coloreSfondo = Color(0xFFF4F6F8);
const Color colorePrincipale = Color(0xFF7F5539); // Marrone
const Color coloreAccento = Color(0xFFFF6B35);    // Arancione

class ArticleDetailScreen extends StatefulWidget {
  final String articleId;

  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  // Stato per l'apertura/chiusura della chat IA laterale
  bool _isChatOpen = false;
  bool _isLogin = false;
  bool _isLoading = true;

  Articolo? _article;
  Future<void> _checkLoginStatus() async{
    String? accessToken = SharedPreferenceManager.instance.getString('access');
    setState(() {
      _isLogin= accessToken != null;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

Future<void> _loadArticle() async {
      setState(() {
        _isLoading = true;
      });
      try {
        final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/articles/${widget.articleId}'),
        );
        if (response.statusCode != 200) {
          throw Exception('Errore ${response.statusCode} nel recupero articolo');
        }
        final Map<String, dynamic> data = jsonDecode(response.body);
        // L'endpoint GET /articles/{id} restituisce { status, article, chunks }
        final Map<String, dynamic>? articleJson = data['article'];
        if (articleJson == null) {
          throw Exception('Articolo non trovato nella risposta');
        }

        final articolo = Articolo.fromJson(articleJson);
        if (!mounted) return;
        setState(() {
          _article = articolo;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
}
  @override
  Widget build(BuildContext context) {
    // Breakpoint per impilare Immagine e Metadati Manuali su schermi piccoli
    bool isWideScreen = MediaQuery.of(context).size.width > 900;
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: coloreSfondo,
        body: Center(child: CircularProgressIndicator(color: colorePrincipale)),
      );
    }
    if ( _article == null) {
      return Scaffold(
        backgroundColor: coloreSfondo,
        appBar: AppBar(
          backgroundColor: colorePrincipale,
          foregroundColor: Colors.white,
          title: const Text('Dettaglio Articolo'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Articolo non trovato", textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadArticle, child: const Text("Riprova")),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: coloreSfondo,
      appBar: AppBar(
        backgroundColor: colorePrincipale,
        foregroundColor: Colors.white,
        title: const Text('Dettaglio Articolo', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),


      // tasto chat chiusa

      floatingActionButton: !_isChatOpen
          ? FloatingActionButton.extended(
        onPressed: () => setState(() => _isChatOpen = true),
        backgroundColor: coloreAccento,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.chat_bubble_outline, size: 24),
        label: const Text('Chiedi all\'IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )
          : null, // Scompare completamente quando apri la chat

      body: Stack(
        children: [
          // contenuto della pagina
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITOLO
                Text(
                  _article!.title,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: colorePrincipale, height: 1.2),
                ),
                const SizedBox(height: 32),

                // IMMAGINE
                if (isWideScreen)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildCoverImage()),
                      const SizedBox(width: 40),
                      // metadati manuali
                      Expanded(flex: 5, child: _buildManualMetadata()),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverImage(),
                      const SizedBox(height: 32),
                      _buildManualMetadata(),
                    ],
                  ),

                const SizedBox(height: 48),

                // matadati IA
                _buildAIMetadata(),
                const SizedBox(height: 48),

                // chunck estrapolati TODO indeciso se lasciarli o toglierli
                _buildExtractedText(),
                const SizedBox(height: 48),

                // button per download
                Wrap(
                  spacing: 24, // Spazio orizzontale
                  runSpacing: 16, // Spazio verticale se lo schermo è troppo stretto
                  children: [
                    _buildActionBtn(Icons.download, "Scarica Documento", () => _scaricaDocumento(), isPrimary: true),
                    _buildActionBtn(Icons.data_object, "Scarica Metadati (JSON)", () => _scaricaFileJson(), isPrimary: false),
                  ],
                ),
                const SizedBox(height: 80), // Spazio finale
              ],
            ),
          ),

          //opacizzazione sfondo quando la chat è aperta
          if (_isChatOpen)
            GestureDetector(
              onTap: () => setState(() => _isChatOpen = false),
              child: AnimatedOpacity(
                opacity: _isChatOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(color: Colors.black.withAlpha(120)),
              ),
            ),

          //pannello laterale chat
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutBack,
            top: 0,
            bottom: 0,
            right: _isChatOpen ? 0 : -450,
            width: 400,
            child: _buildChatPanel(),
          ),
        ],
      ),
    );
  }



  Widget _buildCoverImage() {
    final coverUrl = _article!.coverUrl;
    final hasValidCover = coverUrl.isNotEmpty && !coverUrl.contains('placeholder');

    return Container(
      width: double.infinity,
      height: 350,
      decoration: BoxDecoration(
        color: colorePrincipale.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: colorePrincipale.withAlpha(30), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        image: hasValidCover
            ? DecorationImage(
          image: NetworkImage('${ApiConfig.baseUrl}/articles/${_article!.id}/cover'),
          fit: BoxFit.cover,
        )
            : null,
      ),
      child: !hasValidCover
          ? const Center(child: Icon(Icons.article, size: 100, color: Colors.white70))
          : null,
    );
  }

  Widget _buildManualMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Metadati Manuali"),
        _buildMetadataCard(
          children: [
            _buildDetailRow("Autore", _article!.author),
            _buildTagsRow("Categoria", List<String>.from(_article!.category), colorePrincipale),
            _buildDetailRow("Descrizione", _article!.description),
            _buildTagsRow("Tags", List<String>.from(_article!.tags), colorePrincipale),
          ],
        ),
      ],
    );
  }

  Widget _buildAIMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Analisi IA (Azure OpenAI)"),
        _buildMetadataCard(
          children: [
            _buildDetailRow("Sottotitolo", _article!.subtitle),
            _buildDetailRow("Riassunto", _article!.summary),
            _buildDetailRow("Lingua", _article!.language),
            _buildTagsRow("Parole Chiave", _article!.keywords, coloreAccento),
            const SizedBox(height: 8),
            _buildTagsRow("Entità Rilevate", _article!.entities, Colors.indigo),
          ],
        ),
      ],
    );
  }

  Widget _buildExtractedText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Testo Estrapolato"),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorePrincipale.withAlpha(20)),
            boxShadow: [BoxShadow(color: colorePrincipale.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: const Text(
            "Il testo estratto completo apparirà in questo box. "
                "In produzione, qui verranno renderizzati i frammenti (chunk) provenienti da Cosmos DB o il testo estrapolato originariamente dal Blob Storage.\n\n"
                "L'intelligenza artificiale ha rivoluzionato il modo in cui gestiamo le informazioni nel cloud. "
                "Grazie ai Large Language Models, oggi possiamo estrarre insight in frazioni di secondo...",
            style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorePrincipale)),
    );
  }

  Widget _buildMetadataCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorePrincipale.withAlpha(20)),
        boxShadow: [BoxShadow(color: colorePrincipale.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, color: colorePrincipale, fontSize: 15)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildTagsRow(String label, List<String> tags, Color tagColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, color: colorePrincipale, fontSize: 15)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tagColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tagColor.withAlpha(40)),
                ),
                child: Text(tag, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tagColor)),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onPressed, {required bool isPrimary}) {
    return SizedBox(
      height: 50,
      width: 260,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: isPrimary ? Colors.white : coloreAccento),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? coloreAccento : Colors.white,
          foregroundColor: isPrimary ? Colors.white : coloreAccento,
          side: isPrimary ? BorderSide.none : const BorderSide(color: coloreAccento, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: isPrimary ? 4 : 0,
        ),
      ),
    );
  }


  Widget _buildChatPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: coloreSfondo,
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 25, spreadRadius: 5)],
      ),
      child: Column(
        children: [
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: colorePrincipale,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _isChatOpen = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: coloreAccento,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(54, 36),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Icon(Icons.close,color: Colors.white, size: 20),
                ),

                const Text(
                  'Assistente RAG',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // AREA MESSAGGI
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildChatBubble("Ciao! Fai una domanda specifica su questo articolo.", isAi: true),
              ],
            ),
          ),

          // INPUT CHAT
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Chiedi qualcosa all'IA...",
                      hintStyle: const TextStyle(fontSize: 14),
                      filled: true,
                      fillColor: coloreSfondo,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: coloreAccento,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: () {}), //todo sistemare con controllo del login
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isAi}) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAi ? Colors.white : coloreAccento,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isAi ? const Radius.circular(0) : const Radius.circular(16),
            bottomRight: isAi ? const Radius.circular(16) : const Radius.circular(0),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Text(text, style: TextStyle(color: isAi ? colorePrincipale : Colors.white, fontSize: 15)),
      ),
    );
  }

  Future<void> _scaricaFileJson() async {
    final article = _article;
    if (article == null) return;
    try {
      final pdf = pw.Document();
      final tFont = pw.Font.times();
      final tBold = pw.Font.timesBold();
      final tItalic = pw.Font.timesItalic();

      //scarichiamo l'immagine della copertina

      pw.MemoryImage? coverImage;
      if (article.coverUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(article.coverUrl));
          if (response.statusCode == 200) {
            coverImage = pw.MemoryImage(response.bodyBytes);
          }
        } catch (_) {
          coverImage = null;
        }
      }
      pw.Widget buildRow(String label, String value) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 110,
                child: pw.Text(label, style: pw.TextStyle(font: tBold, fontSize: 12)),
              ),
              pw.Expanded(
                child: pw.Text(
                  value.isNotEmpty ? value : "-",
                  style: pw.TextStyle(font: tFont, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }

      pw.Widget sectionTitle(String title) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
          child: pw.Text(title, style: pw.TextStyle(font: tBold, fontSize: 16)),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Text(
            article.title,
            style: pw.TextStyle(font: tItalic, fontSize: 10, color: PdfColors.grey700),
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Pagina ${context.pageNumber} di ${context.pagesCount}',
              style: pw.TextStyle(font: tFont, fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          build: (pw.Context contextPdf) {
            return [
              pw.Text(article.title, style: pw.TextStyle(font: tBold, fontSize: 24)),
              pw.SizedBox(height: 16),

              if (coverImage != null) ...[
                pw.Center(
                  child: pw.Container(
                    height: 220,
                    child: pw.Image(coverImage, fit: pw.BoxFit.cover),
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              sectionTitle("Informazioni generali"),
              buildRow("ID", article.id),
              buildRow("Caricato il", article.uploadedAt),
              buildRow("URL Blob", article.blobUrl),

              sectionTitle("Metadati Manuali"),
              buildRow("Autore", article.author),
              buildRow("Descrizione", article.description),
              buildRow("Categoria", article.category.join(", ")),
              buildRow("Tags", article.tags.join(", ")),

              sectionTitle("Analisi IA"),
              buildRow("Sottotitolo", article.subtitle),
              buildRow("Lingua", article.language),
              buildRow("Parole chiave", article.keywords.join(", ")),
              buildRow("Entità rilevate", article.entities.join(", ")),
              pw.SizedBox(height: 8),
              pw.Text("Riassunto", style: pw.TextStyle(font: tBold, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text(
                article.summary.isNotEmpty ? article.summary : "-",
                style: pw.TextStyle(font: tFont, fontSize: 12),
              ),
            ];
          },
        ),
      );

      // Conversione del documento in byte ed emissione del download
      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute("download", "Metadati_${article.id}.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (!mounted) return;
      print("Errore nella generazione del PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossibile generare il PDF: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _scaricaDocumento() async {
    final article = _article;
    if (article == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/articles/${article.id}/download'),
      );

      if (response.statusCode != 200) {
        throw Exception('Errore ${response.statusCode} durante il download');
      }

      final contentType = response.headers['content-type'] ?? 'application/octet-stream';

      // Proviamo a recuperare il nome file dall'header Content-Disposition
      // inviato dal backend; se manca, usiamo un fallback con l'id articolo.
      String filename = 'articolo_${article.id}';
      final disposition = response.headers['content-disposition'];
      if (disposition != null) {
        final match = RegExp(r'filename="?([^"]+)"?').firstMatch(disposition);
        if (match != null && match.group(1) != null) {
          filename = match.group(1)!;
        }
      }

      final blob = html.Blob([response.bodyBytes], contentType);
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute("download", filename)
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossibile scaricare il documento: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

}