import 'package:flutter/material.dart';

// Importa i colori (puoi anche metterli in un file theme.dart separato)
const Color coloreSfondo = Color(0xFFF4F6F8);
const Color colorePrincipale = Color(0xFF7F5539);
const Color coloreAccento = Color(0xFFFF6B35);

class InformazioniScreen extends StatelessWidget {
  const InformazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: coloreSfondo,
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