import 'package:flutter/material.dart';

// --- COLORI DESIGN SYSTEM 60-30-10 ---
const Color coloreSfondo = Color(0xFFF4F6F8);
const Color colorePrincipale = Color(0xFF7F5539);
const Color coloreAccento = Color(0xFFFF6B35);

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();


  final List<String> _selectedCategories = [];
  final List<String> _selectedTags = [];


  final List<String> _defaultCategories = ['Politica', 'Economia', 'Tecnologia', 'Sport', 'Cultura', 'Scienza'];
  bool _isCustomCategory = false; // Flag per mostrare il campo "Altro..."


  String? _documentFileName;
  String? _coverFileName;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: coloreSfondo,
      body: CustomScrollView(
        slivers: [

          // APP BAR

          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: colorePrincipale,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'Upload Articolo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: colorePrincipale),
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.upload_file,
                      size: 150,
                      color: coloreAccento.withAlpha(40),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CONTENUTO DELLA PAGINA

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("1. Selezione File (Obbligatorio)"),
                  const SizedBox(height: 16),
                  _buildUnifiedFileUploader(),

                  const SizedBox(height: 32),
                  _buildSectionTitle("2. Dati dell'Articolo (Metadati)"),
                  const SizedBox(height: 16),

                  _buildTextField("Titolo dell'articolo", _titleController, Icons.title),
                  const SizedBox(height: 16),

                  _buildTextField("Autore", _authorController, Icons.person_outline),
                  const SizedBox(height: 16),

                  // --- SEZIONE CATEGORIE (Chips + Dropdown) ---
                  _buildCategoryMultiSelect(),
                  const SizedBox(height: 16),

                  _buildTextField("Descrizione breve", _descriptionController, Icons.description_outlined, maxLines: 3),
                  const SizedBox(height: 16),

                  // --- SEZIONE TAGS (Chips + TextField) ---
                  _buildTagsInput(),

                  const SizedBox(height: 48),

                  _buildtButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }



  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorePrincipale));
  }

  Widget _buildUnifiedFileUploader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorePrincipale.withAlpha(30)),
        boxShadow: [
          BoxShadow(color: colorePrincipale.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildFilePickerRow(
            icon: Icons.description,
            title: "Documento (.txt, .pdf, .docx)",
            fileName: _documentFileName,
            onTap: () => setState(() => _documentFileName = "articolo_scienza.pdf"), // Mock
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider()),
          _buildFilePickerRow(
            icon: Icons.image,
            title: "Copertina (.png, .jpg) - Opzionale",
            fileName: _coverFileName,
            onTap: () => setState(() => _coverFileName = "cover_img.jpg"), // Mock
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerRow({required IconData icon, required String title, String? fileName, required VoidCallback onTap}) {
    bool hasFile = fileName != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFile ? coloreAccento.withAlpha(30) : coloreSfondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: hasFile ? coloreAccento : colorePrincipale, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorePrincipale)),
                  const SizedBox(height: 4),
                  Text(
                    hasFile ? fileName : "Nessun file selezionato",
                    style: TextStyle(
                      fontSize: 13,
                      color: hasFile ? coloreAccento : colorePrincipale.withAlpha(150),
                      fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(hasFile ? Icons.check_circle : Icons.add_circle_outline, color: hasFile ? Colors.green : colorePrincipale.withAlpha(100))
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: colorePrincipale, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorePrincipale.withAlpha(150), fontSize: 14),
        prefixIcon: Icon(icon, color: colorePrincipale.withAlpha(150), size: 20),
        filled: true, fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorePrincipale.withAlpha(30))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: coloreAccento, width: 2)),
      ),
    );
  }

  // --- GESTIONE CATEGORIE MULTIPLE E CUSTOM ---
  Widget _buildCategoryMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: _selectedCategories.map((cat) {
                return Chip(
                  label: Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  backgroundColor: coloreAccento,
                  deleteIconColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  onDeleted: () => setState(() => _selectedCategories.remove(cat)),
                );
              }).toList(),
            ),
          ),

        Row(
          children: [
            Expanded(
              child: _isCustomCategory
                  ? TextField(
                controller: _customCategoryController,
                style: const TextStyle(color: colorePrincipale, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Scrivi nuova categoria e premi Invio',
                  prefixIcon: const Icon(Icons.edit, color: coloreAccento, size: 20),
                  filled: true, fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: coloreAccento)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: coloreAccento, width: 2)),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty && !_selectedCategories.contains(val.trim())) {
                    setState(() {
                      _selectedCategories.add(val.trim());
                      _customCategoryController.clear();
                      _isCustomCategory = false; // Ritorna al menu a tendina
                    });
                  }
                },
              )
                  : DropdownButtonFormField<String>(
                icon: const Icon(Icons.arrow_drop_down, color: colorePrincipale),
                decoration: InputDecoration(
                  labelText: 'Aggiungi una categoria',
                  prefixIcon: Icon(Icons.category_outlined, color: colorePrincipale.withAlpha(150), size: 20),
                  filled: true, fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorePrincipale.withAlpha(30))),
                ),
                items: [..._defaultCategories, 'Altro...'].map((String category) {
                  return DropdownMenuItem<String>(value: category, child: Text(category, style: const TextStyle(color: colorePrincipale)));
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue == 'Altro...') {
                    setState(() => _isCustomCategory = true); // Mostra campo testuale
                  } else if (newValue != null && !_selectedCategories.contains(newValue)) {
                    setState(() => _selectedCategories.add(newValue)); // Aggiunge il chip
                  }
                },
              ),
            ),
            // Bottone "X" per annullare l'inserimento manuale e tornare al Dropdown
            if (_isCustomCategory)
              IconButton(
                icon: const Icon(Icons.close, color: colorePrincipale),
                onPressed: () => setState(() {
                  _isCustomCategory = false;
                  _customCategoryController.clear();
                }),
              )
          ],
        ),
      ],
    );
  }

  // --- GESTIONE TAGS MULTIPLI ---
  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Mostra i Tag Selezionati come Chips
        if (_selectedTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: _selectedTags.map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  backgroundColor: colorePrincipale.withAlpha(200), // Colore diverso per i tag
                  deleteIconColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  onDeleted: () => setState(() => _selectedTags.remove(tag)),
                );
              }).toList(),
            ),
          ),
        TextField(
          controller: _tagsController,
          style: const TextStyle(color: colorePrincipale, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Scrivi un Tag e premi Invio',
            prefixIcon: Icon(Icons.local_offer_outlined, color: colorePrincipale.withAlpha(150), size: 20),
            filled: true, fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorePrincipale.withAlpha(30))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: coloreAccento, width: 2)),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty && !_selectedTags.contains(val.trim())) {
              setState(() {
                _selectedTags.add(val.trim());
                _tagsController.clear();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildtButton() {
    return Center(
      child: SizedBox(
        width: 250, // Dimensione fissa centrale e molto più elegante
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () {
            debugPrint("--- ESECUZIONE UPLOAD ---");
            debugPrint("File: $_documentFileName");
            debugPrint("Categorie (List): $_selectedCategories");
            debugPrint("Tags (List): $_selectedTags");
          },
          icon: const Icon(Icons.cloud_upload, color: Colors.white, size: 24),
          label: const Text(
            'CARICA ARTICOLO',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: coloreAccento,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), // Molto arrotondato
            elevation: 4,
            shadowColor: coloreAccento.withAlpha(100),
          ),
        ),
      ),
    );
  }
}