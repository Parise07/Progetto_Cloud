import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:frontend/pages/upload_page.dart';

import '../shared_preferences.dart';
import 'cronologia_page.dart';
import 'login_page.dart';

// Importa i colori (puoi anche metterli in un file theme.dart separato)
const Color coloreSfondo = Color(0xFFF4F6F8);
const Color colorePrincipale = Color(0xFF7F5539);
const Color coloreAccento = Color(0xFFFF6B35);

class InformazioniScreen extends StatefulWidget {
  const InformazioniScreen({super.key});

  @override
  State<InformazioniScreen> createState() => _InformazioniScreenState();
}

class _InformazioniScreenState extends State<InformazioniScreen> {
  bool _isLogin = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    String? token = SharedPreferenceManager.instance.getString('access');
    setState(() {
      _isLogin = token != null;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: coloreSfondo,
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
                await SharedPreferenceManager.clear();

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
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // --- App Bar Animata ---
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: colorePrincipale,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'Info Sistema',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: colorePrincipale),
                  // Pattern o icona di sfondo
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.newspaper,
                      size: 150,
                      color: coloreAccento.withAlpha(40), // Effetto watermark
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Contenuto della Pagina ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderProgetto(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Architettura & Tecnologie'),
                  const SizedBox(height: 12),
                  _buildTechCard(
                    Icons.cloud_done_outlined,
                    'Infrastruttura Cloud',
                    'Microsoft Azure (Blob Storage, Cosmos DB NoSQL, AI Search)',
                  ),
                  _buildTechCard(
                    Icons.psychology_outlined,
                    'Intelligenza Artificiale (RAG)',
                    'Azure OpenAI (GPT-4o-mini, text-embedding-ada-002) orchestrato tramite LangChain.',
                  ),
                  _buildTechCard(
                    Icons.dns_outlined,
                    'Backend & Core',
                    'Python FastAPI (Architettura Decoupled Asincrona).',
                  ),
                  _buildTechCard(
                    Icons.security_outlined,
                    'Sicurezza & Identity',
                    'Keycloak (OAuth2.0 / OpenID Connect JWT).',
                  ),
                  _buildTechCard(
                    Icons.phone_iphone_outlined,
                    'Frontend Client',
                    'Flutter & Dart.',
                  ),
                  const SizedBox(height: 32),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header con i dati dello studente e del corso
  Widget _buildHeaderProgetto() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorePrincipale.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: colorePrincipale.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sistema RAG per l\'Archiviazione e Ricerca di Notizie',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorePrincipale,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_outline, 'Sviluppato da:', 'Antonio Parise (Matricola: 276697)'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.school_outlined, 'Corso di Laurea:', 'Ingegneria Informatica'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.menu_book_outlined, 'Esame:', 'Sistemi Distribuiti e Cloud Computing (a.a. 2025/26)'),
        ],
      ),
    );
  }

  /// Costruisce una riga informativa testuale
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: coloreAccento),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: colorePrincipale, height: 1.4),
              children: [
                TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Titolo di Sezione
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: colorePrincipale,
      ),
    );
  }

  /// Card per le tecnologie utilizzate
  Widget _buildTechCard(IconData icon, String title, String description) {
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
              color: colorePrincipale.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: coloreSfondo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colorePrincipale, size: 24),
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorePrincipale.withAlpha(180),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Footer decorativo in fondo alla pagina
  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.cloud_done, color: coloreAccento.withAlpha(100), size: 32),
          const SizedBox(height: 8),
          Text(
            'Powered by Azure Cloud & Flutter',
            style: TextStyle(
              fontSize: 12,
              color: colorePrincipale.withAlpha(130),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32), // Spazio extra a fondo pagina
        ],
      ),
    );
  }
}