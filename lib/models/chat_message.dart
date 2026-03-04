enum MessageType {
  text,
  media,
  system,
  missedCall,
  callEvent,
  poll,
  deletedMessage,
}

class ChatMessage {
  final String id;
  final String? sender;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final bool isEdited;

  const ChatMessage({
    required this.id,
    this.sender,
    required this.text,
    required this.timestamp,
    required this.type,
    this.isEdited = false,
  });

  bool get isSystem =>
      type == MessageType.system ||
      type == MessageType.missedCall ||
      sender == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender,
    'text': text,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'type': type.index,
    'isEdited': isEdited,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    sender: json['sender'] as String?,
    text: json['text'] as String,
    isEdited: json['isEdited'] as bool? ?? false,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    type: MessageType.values[json['type'] as int],
  );

  @override
  String toString() => 'ChatMessage(sender: $sender, text: $text)';
}
