class MessageModel {
  final String content;
  final bool isSent;
  final DateTime timestamp;

  MessageModel({
    required this.content,
    required this.isSent,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'isSent': isSent,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        content: json['content'],
        isSent: json['isSent'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}