import 'dart:core';

class Articolo {
    final String id;
    final String title;
    final String author;
    final List<String> category;
    final List<String> tags;
    final String coverUrl;
    final String blobUrl;
    final String uploadedAt;

    Articolo({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.tags,
    required this.coverUrl,
    required this.blobUrl,
    required this.uploadedAt,
  });
  factory Articolo.fromJson(Map<String, dynamic> json) {
    final manual = json['manual_metadata'] ?? json['manual'] ?? json;
    return Articolo(
      id: json['id'] ?? '',
      title: manual['title'] ?? 'Senza titolo',
      author: manual['author'] ?? 'Autore sconosciuto',
      category: (manual['category'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tags: (manual['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      coverUrl: json['cover_url'] ?? '',
      blobUrl: json['blob_url'] ?? '',
      uploadedAt: json['uploaded_at'] ?? json['_ts']?.toString() ?? '',
    );
  }
    Map<String, dynamic> toMap() {
      return {
        'id': id,
        'title': title,
        'author': author,
        'category': category,
        'tags':tags,
        'cover_url': coverUrl,
        'blob_url': blobUrl,
        'uploaded_at': uploadedAt,
      };
    }
}