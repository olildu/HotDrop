class MessageModel {
  final String message;
  final String sender;

  MessageModel({
    required this.message,
    required this.sender,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      message: map['message'] ?? '',
      sender: map['sender'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'sender': sender,
    };
  }
}
