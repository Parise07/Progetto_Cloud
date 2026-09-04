import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/pages/cronologia_page.dart';
import 'package:http/http.dart' as http;
import 'package:desktop_drop/desktop_drop.dart';
import '../api_config.dart';
import '../main.dart';
import '../shared_preferences.dart';
import 'package:frontend/categorypicker.dart';
import 'info_page.dart';
import 'login_page.dart';

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


  List<String> _categories = [];
  bool _isCustomCategory = false;
  bool _isLogin= false;

  String? _documentFileName;
  String? _coverFileName;

  PlatformFile? _documentFile;
  PlatformFile? _coverFile;

  bool _isDraggingDoc = false;
  bool _isDraggingCover = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadCategories();
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
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    String? accessToken = SharedPreferenceManager.instance.getString('access');
    if (mounted) {
      setState(() {
        _isLogin = accessToken != null;
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
                await SharedPreferenceManager.clear();

                setState(() {
                  _isLogin=false;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CronologiaScreen()),
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
                  MaterialPageRoute(builder: (context) => const MyApp()),
                );
              } else{
                showErrorDialog("É necessario il login per poter visualizzare la cronologia. Accedi o registrati. ");
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
            title: "Documento (.txt, .pdf, .docx, .md)",
            fileName: _documentFileName,
            isDragging: _isDraggingDoc,
            onDragStateChanged: (dragging) => setState(() => _isDraggingDoc = dragging),
            onFileDropped: (droppedFile) {
              setState(() {
                _documentFile = droppedFile;
                _documentFileName = droppedFile.name;
              });
            },
            onTap: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['txt', 'pdf', 'docx', 'md'],
                withData: true,
              );
              if (result != null) {
                setState(() {
                  _documentFile = result.files.first;
                  _documentFileName = _documentFile!.name;
                });
              }
            },
            onClear: () {
              setState(() {
                _documentFile = null;
                _documentFileName = null;
              });
            },
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider()),
          _buildFilePickerRow(
            icon: Icons.image,
            title: "Copertina (.png, .jpg) - Opzionale",
            fileName: _coverFileName,
            isDragging: _isDraggingCover,
            onDragStateChanged: (dragging) => setState(() => _isDraggingCover = dragging),
            onFileDropped: (droppedFile) {
              setState(() {
                _coverFile = droppedFile;
                _coverFileName = droppedFile.name;
              });
            },
            onTap: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                withData: true,
              );
              if (result != null) {
                setState(() {
                  _coverFile = result.files.first;
                  _coverFileName = _coverFile!.name;
                });
              }
            },
            onClear: () {
              setState(() {
                _coverFile = null;
                _coverFileName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerRow({
    required IconData icon,
    required String title,
    String? fileName,
    required VoidCallback onTap,
    required Function(PlatformFile) onFileDropped,
    required bool isDragging,
    required Function(bool) onDragStateChanged,
    required VoidCallback onClear, // <-- NUOVO PARAMETRO
  }) {
    bool hasFile = fileName != null;
    return DropTarget(
      onDragEntered: (details) => onDragStateChanged(true),
      onDragExited: (details) => onDragStateChanged(false),
      onDragDone: (details) async {
        onDragStateChanged(false);
        if (details.files.isNotEmpty) {
          final xFile = details.files.first;
          final bytes = await xFile.readAsBytes();
          final platformFile = PlatformFile(name: xFile.name, size: bytes.length, bytes: bytes);
          onFileDropped(platformFile);
        }
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDragging ? coloreAccento.withAlpha(20) : Colors.white.withAlpha(1),
            borderRadius: BorderRadius.circular(8),
            border: isDragging
                ? Border.all(color: coloreAccento, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
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
                      hasFile ? fileName : "Clicca o trascina qui il file",
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
              // FIX: SE C'È UN FILE MOSTRA LA 'X' ROSSA, ALTRIMENTI L'ICONA DI UPLOAD
              if (hasFile)
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
                  onPressed: onClear, // <-- Azzera il file selezionato!
                  tooltip: 'Rimuovi file',
                )
              else
                Icon(Icons.cloud_upload_outlined, color: colorePrincipale.withAlpha(100), size: 28)
            ],
          ),
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
                  : InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final String? selected = await showCategoryPicker(
                    context,
                    categories: _categories,
                    showAddCustomOption: true,
                    title: 'Aggiungi una categoria',
                  );
                  if (selected == kCustomCategoryOption) {
                    setState(() => _isCustomCategory = true); // Mostra campo testuale
                  } else if (selected != null && !_selectedCategories.contains(selected)) {
                    setState(() => _selectedCategories.add(selected)); // Aggiunge il chip
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Aggiungi una categoria',
                    prefixIcon: Icon(Icons.category_outlined, color: colorePrincipale.withAlpha(150), size: 20),
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: colorePrincipale),
                    filled: true, fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorePrincipale.withAlpha(30))),
                  ),
                  child: Text(
                    'Seleziona una categoria...',
                    style: TextStyle(color: colorePrincipale.withAlpha(150), fontSize: 14),
                  ),
                ),
              ),
            ),
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

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          onPressed: () async {
            if (_documentFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Il documento è obbligatorio!')),
              );
              return;
            }

            // Mostriamo un caricamento base
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Caricamento in corso...')),
            );

            try {
              var uri = Uri.parse('${ApiConfig.baseUrl}/articles/upload');
              var request = http.MultipartRequest('POST', uri);

              String? token = SharedPreferenceManager.instance.getString('access');
              if (token != null) {
                request.headers['Authorization'] = 'Bearer $token';
              }

              request.fields['title'] = _titleController.text;
              request.fields['author'] = _authorController.text;
              request.fields['description'] = _descriptionController.text;

              for (String cat in _selectedCategories) {
                request.files.add(http.MultipartFile.fromString('category', cat));
              }

              for (String tag in _selectedTags) {
                request.files.add(http.MultipartFile.fromString('tags', tag));
              }

              if (_documentFile != null && _documentFile!.bytes != null) {
                request.files.add(http.MultipartFile.fromBytes(
                  'file',
                  _documentFile!.bytes!,
                  filename: _documentFile!.name,
                ));
              }

              if (_coverFile != null && _coverFile!.bytes != null) {
                request.files.add(http.MultipartFile.fromBytes(
                  'cover_image',
                  _coverFile!.bytes!,
                  filename: _coverFile!.name,
                ));
              }

              var streamedResponse = await request.send();
              var response = await http.Response.fromStream(streamedResponse);

              if (response.statusCode == 201) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Articolo caricato con successo!'), backgroundColor: Colors.green),
                );
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                        (route) => false,
                  );
                }
              } else {
                debugPrint("Errore: ${response.body}");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Errore durante il caricamento: ${response.statusCode}'), backgroundColor: Colors.red),
                );
              }
            } catch (e) {
              debugPrint("Eccezione durante l'upload: $e");
            }
          },
          icon: const Icon(Icons.cloud_upload, color: Colors.white, size: 24),
          label: const Text(
            'CARICA ARTICOLO',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: coloreAccento,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            elevation: 4,
            shadowColor: coloreAccento.withAlpha(100),
          ),
        ),
      ),
    );
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