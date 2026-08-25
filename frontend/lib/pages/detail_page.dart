import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../shared_preferences.dart';
import "package:pdf/widgets.dart" as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';



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

  // --- DATI MOCK ---
  final Map<String, dynamic> _mockArticle = {
    'title': 'Le nuove frontiere dell\'Intelligenza Artificiale nel 2026',
    'cover_url': 'https://picsum.photos/800/400',
    'manual': {
      'author': 'Antonio Parise',
      'category': 'Tecnologia',
      'description': 'Un\'analisi approfondita sui nuovi modelli generativi multimodali.',
      'tags': ['AI', 'Cloud', 'Innovazione']
    },
    'ia_metadata': {
      'subtitle': 'Come i modelli LLM stanno ridefinendo il Cloud Computing',
      'summary': 'L\'articolo esplora l\'integrazione nativa dell\'IA nei sistemi cloud-native, evidenziando miglioramenti in efficienza e sicurezza.',
      'keywords': ['LLM', 'Cloud-Native', 'Integrazione', 'Sicurezza'],
      'language': 'it',
      'entities': ['Organizzazione: OpenAI', 'Tecnologia: Azure', 'Concetto: RAG']
    }
  };

  Future<void> _checkLoginStatus() async{
    String? accessToken = SharedPreferenceManager.instance.getString('access');
    setState(() {
      _isLogin= accessToken != null;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Breakpoint per impilare Immagine e Metadati Manuali su schermi piccoli
    bool isWideScreen = MediaQuery.of(context).size.width > 900;

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
                  _mockArticle['title'],
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
                    _buildActionBtn(Icons.download, "Scarica Documento", () {}, isPrimary: true),
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
    return Container(
      width: double.infinity,
      height: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: colorePrincipale.withAlpha(30), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        image: DecorationImage(
          image: NetworkImage(_mockArticle['cover_url']),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildManualMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Metadati Manuali"),
        _buildMetadataCard(
          children: [
            _buildDetailRow("Autore", _mockArticle['manual']['author']),
            _buildDetailRow("Categoria", _mockArticle['manual']['category']),
            _buildDetailRow("Descrizione", _mockArticle['manual']['description']),
            _buildTagsRow("Tags", List<String>.from(_mockArticle['manual']['tags']), colorePrincipale),
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
            _buildDetailRow("Sottotitolo", _mockArticle['ia_metadata']['subtitle']),
            _buildDetailRow("Riassunto", _mockArticle['ia_metadata']['summary']),
            _buildDetailRow("Lingua", _mockArticle['ia_metadata']['language'].toString().toUpperCase()),
            _buildTagsRow("Parole Chiave", List<String>.from(_mockArticle['ia_metadata']['keywords']), coloreAccento),
            const SizedBox(height: 8),
            _buildTagsRow("Entità Rilevate", List<String>.from(_mockArticle['ia_metadata']['entities']), Colors.indigo),
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
    try {
      final pdf = pw.Document();

      // Carichiamo l'immagine di sfondo dagli asset locali usando rootBundle
      final imageBytes = await rootBundle.load('assets/images/Sfondo_indicazioni.jpeg');
      final image = pw.MemoryImage(imageBytes.buffer.asUint8List());

      // Definiamo i font standard inclusi nel PDF per un aspetto Serif classico
      final tFont = pw.Font.times();
      final tBold = pw.Font.timesBold();
      final tItalic = pw.Font.timesItalic();

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(600, 1000, marginAll: 0),
          build: (pw.Context contextPdf) {
            return pw.Stack(
              children: [
                // Inseriamo lo sfondo decorato per coprire l'intera pagina del PDF
                pw.Positioned.fill(
                  child: pw.Image(image, fit: pw.BoxFit.fill),
                ),
                // Contenuto testuale allineato e bloccato dentro la cornice
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 55),
                  child: pw.Column(
                    children: [
                      pw.SizedBox(height: 220), // Spazio per scendere sotto i ricami in alto
                      pw.Text(
                        "PROMEMORIA LAUREA",
                        style: pw.TextStyle(
                          font: tBold,
                          fontSize: 32,
                          color: PdfColor.fromHex('#3C0202'),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        "DI IRENE 🎓",
                        style: pw.TextStyle(
                          font: tBold,
                          fontSize: 32,
                          color: PdfColor.fromHex('#3C0202'),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Spacer(flex: 1),
                      pw.Text(
                        "Ciao $nome,",
                        style: pw.TextStyle(
                          font: tItalic,
                          fontSize: 22,
                          color: PdfColor.fromHex('#3C0202'),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        "questo è il tuo promemoria per l'evento!",
                        style: pw.TextStyle(
                          font: tItalic,
                          fontSize: 22,
                          color: PdfColor.fromHex('#3C0202'),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 20),
                      pw.Container(
                        width: 320,
                        height: 1.5,
                        color: PdfColor.fromHex('#3C0202'),
                      ),
                      pw.Spacer(flex: 1),
                      // Blocco dei dati logistici centrato orizzontalmente ma allineato a sinistra internamente
                      pw.Align(
                        alignment: pw.Alignment.center,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              "📅 Data: [Inserisci la tua Data]",
                              style: pw.TextStyle(
                                font: tBold,
                                fontSize: 18,
                                color: PdfColor.fromHex('#3C0202'),
                              ),
                            ),
                            pw.SizedBox(height: 15),
                            pw.Text(
                              "🕒 Ora: [Inserisci il tuo Orario]",
                              style: pw.TextStyle(
                                font: tBold,
                                fontSize: 18,
                                color: PdfColor.fromHex('#3C0202'),
                              ),
                            ),
                            pw.SizedBox(height: 15),
                            pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text(
                                  "📍 Luogo: ",
                                  style: pw.TextStyle(
                                    font: tBold,
                                    fontSize: 18,
                                    color: PdfColor.fromHex('#3C0202'),
                                  ),
                                ),
                                // LINK INTERATTIVO E CLICCABILE DENTRO IL PDF SCARICATO!
                                pw.UrlLink(
                                  destination: "https://maps.app.goo.gl/CGdiNsgpwh5dGUgRA",
                                  child: pw.Text(
                                    "Apri Mappa 🗺️",
                                    style: pw.TextStyle(
                                      font: tBold,
                                      fontSize: 18,
                                      color: PdfColors.blue800,
                                      decoration: pw.TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.Spacer(flex: 2),
                      pw.Text(
                        "Non vedo l'ora di festeggiare insieme! 🥂",
                        style: pw.TextStyle(
                          font: tItalic,
                          fontSize: 20,
                          color: PdfColor.fromHex('#3C0202'),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 220), // Spazio inferiore per non coprire i fiori
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Conversione del documento in byte ed emissione del download
      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute("download", "Promemoria_Laurea_Irene.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print("Errore nella generazione del PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossibile generare il PDF. Verifica la posizione dell'immagine."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

}