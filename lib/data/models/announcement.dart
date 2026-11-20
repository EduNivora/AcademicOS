class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final body = json['body']?.toString().trim() ?? '';
    final publishedAt = DateTime.tryParse(
      json['published_at']?.toString() ?? '',
    );

    if (id.isEmpty || title.isEmpty || body.isEmpty || publishedAt == null) {
      throw const FormatException('Invalid announcement payload.');
    }

    return Announcement(
      id: id,
      title: title,
      body: body,
      publishedAt: publishedAt.toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'published_at': publishedAt.toUtc().toIso8601String(),
      };
}
