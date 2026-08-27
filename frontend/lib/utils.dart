import 'dart:core';

class Articolo {
    final String id;
    final String title;
    final String user_id;
    final String author;
    final String description;
    final List<String> category;
    final List<String> tags;
    final String coverUrl;
    final String blobUrl;
    final String uploadedAt;
    final String subtitle;
    final String summary;
    final List<String> keywords;
    final String language;
    final List<String> entities;



    Articolo({
      required this.id,
      required this.title,
      required this.user_id,
      required this.author,
      required this.description,
      required this.category,
      required this.tags,
      required this.coverUrl,
      required this.blobUrl,
      required this.uploadedAt,
      required this.subtitle,
      required this.summary,
      required this.entities,
      required this.keywords,
      required this.language,

  });
  factory Articolo.fromJson(Map<String, dynamic> json) {
    final manual = json['manual_metadata'] ?? json['manual'] ?? json;
    final ia = json['IA_metadata'];
    return Articolo(
      id: json['id'] ?? '',
      title: manual['title'] ?? 'Senza titolo',
      author: manual['author'] ?? 'Autore sconosciuto',
      description: manual['description'] ?? 'Nessuna descrizione trovata',
      user_id: manual['user_id'] ?? 'Nessuno user collegato',
      category: (manual['category'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tags: (manual['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      coverUrl: json['cover_url'] ?? '',
      blobUrl: json['blob_url'] ?? '',
      uploadedAt: json['uploaded_at'] ?? json['_ts']?.toString() ?? '',
      subtitle : ia?['subtitle'] ?? 'Nessun sottotilo trovato',
      summary: ia?['summary'] ?? 'Nessun riassunto trovato',
      keywords: (ia?['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      entities: (ia?['entities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      language: ia?['language'] ?? 'Lingua non rilevata',
    );
  }
    Map<String, dynamic> toMap() {
      return {
        'id': id,
        'title': title,
        'user_id':user_id,
        'author': author,
        'description': description,
        'category': category,
        'tags':tags,
        'cover_url': coverUrl,
        'blob_url': blobUrl,
        'uploaded_at': uploadedAt,
        'subtitle': subtitle,
        'summary': summary,
        'keywords':keywords,
        'entities': entities,
        'language':language,
      };
    }
}