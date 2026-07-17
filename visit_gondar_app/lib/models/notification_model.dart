class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;     // 'alert' | 'info' | 'warning'
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id:        json['id'] as String,
        title:     json['title'] as String,
        body:      json['body'] as String,
        type:      json['type'] as String,
        isRead:    json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'title':    title,
    'body':     body,
    'type':     type,
    'is_read':  isRead,
  };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id, title: title, body: body, type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
