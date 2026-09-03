import 'package:flutter/material.dart';

// --- COLORI DESIGN SYSTEM 60-30-10 (stessi usati nel resto dell'app) ---
const Color _colorePrincipale = Color(0xFF7F5539);
const Color _coloreAccento = Color(0xFFFF6B35);
const Color _coloreSfondo = Color(0xFFF4F6F8);

/// Valore speciale restituito da [showCategoryPicker] quando l'utente
/// sceglie di aggiungere una categoria nuova (usato nella pagina di upload).
const String kCustomCategoryOption = '__custom__';

/// Mostra un pannello a comparsa (bottom sheet) con l'elenco delle categorie
/// raggruppate in sezioni alfabetiche con intestazioni "sticky" (tipo rubrica
/// telefonica), realizzato solo con widget nativi Flutter.
///
/// Ritorna:
/// - il nome della categoria scelta dall'utente
/// - 'Tutte' se [showAllOption] è true e l'utente sceglie quella voce
/// - [kCustomCategoryOption] se [showAddCustomOption] è true e l'utente
///   sceglie di aggiungerne una nuova
/// - null se l'utente chiude il pannello senza scegliere nulla
Future<String?> showCategoryPicker(
    BuildContext context, {
      required List<String> categories,
      bool showAllOption = false,
      bool showAddCustomOption = false,
      String title = 'Seleziona categoria',
    }) {
  // Raggruppamento alfabetico (case-insensitive)
  final List<String> sorted = [...categories]
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final Map<String, List<String>> grouped = {};
  for (final cat in sorted) {
    final String letter = cat.trim().isNotEmpty ? cat.trim()[0].toUpperCase() : '#';
    grouped.putIfAbsent(letter, () => []).add(cat);
  }
  final List<String> letters = grouped.keys.toList()..sort();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _colorePrincipale,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: _colorePrincipale),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                if (showAllOption || showAddCustomOption)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (showAllOption)
                          ActionChip(
                            avatar: const Icon(Icons.apps, size: 16, color: Colors.white),
                            label: const Text('Tutte',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: _colorePrincipale,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                            onPressed: () => Navigator.pop(context, 'Tutte'),
                          ),
                        if (showAddCustomOption)
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Nuova categoria',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: _coloreAccento,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                            onPressed: () => Navigator.pop(context, kCustomCategoryOption),
                          ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: categories.isEmpty
                      ? const Center(
                    child: Text(
                      'Nessuna categoria disponibile',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      for (final letter in letters) ...[
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _LetterHeaderDelegate(letter: letter),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final String cat = grouped[letter]![index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.label_outline,
                                    size: 18, color: _coloreAccento),
                                title: Text(
                                  cat,
                                  style: const TextStyle(color: _colorePrincipale, fontSize: 14),
                                ),
                                onTap: () => Navigator.pop(context, cat),
                              );
                            },
                            childCount: grouped[letter]!.length,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Delegate per l'intestazione di sezione "sticky" (lettera dell'alfabeto).
class _LetterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String letter;

  _LetterHeaderDelegate({required this.letter});

  @override
  double get minExtent => 32;

  @override
  double get maxExtent => 32;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: _coloreSfondo,
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: _coloreAccento,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LetterHeaderDelegate oldDelegate) => oldDelegate.letter != letter;
}