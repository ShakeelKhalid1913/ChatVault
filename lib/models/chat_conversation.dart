import 'dart:convert';
import 'chat_message.dart';

enum ChatPlatform { whatsapp, instagram, telegram, facebook }

class ChatConversation {
  final String id;
  final String title;
  final List<String> participants;
  final String myName;
  final List<ChatMessage> messages;
  final ChatPlatform platform;
  final DateTime importedAt;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.participants,
    required this.myName,
    required this.messages,
    required this.platform,
    required this.importedAt,
  });

  String get lastMessagePreview {
    if (messages.isEmpty) return '';
    final last = messages.last;
    if (last.type == MessageType.media) return '📷 Media';
    if (last.type == MessageType.missedCall) return '📞 ${last.text}';
    if (last.isSystem) return last.text;
    final prefix = last.sender == myName ? 'You: ' : '${last.sender ?? ''}: ';
    final text = last.text.replaceAll('\n', ' ');
    return '$prefix${text.length > 40 ? '${text.substring(0, 40)}…' : text}';
  }

  DateTime? get lastMessageTime =>
      messages.isEmpty ? null : messages.last.timestamp;

  int get messageCount => messages.length;

  String get otherParticipantName {
    final others = participants.where((p) => p != myName).toList();
    if (others.isEmpty) return title;
    return others.join(', ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'participants': participants,
    'myName': myName,
    'messages': messages.map((m) => m.toJson()).toList(),
    'platform': platform.index,
    'importedAt': importedAt.millisecondsSinceEpoch,
  };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final msgsJson = json['messages'] as List<dynamic>;
    return ChatConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      participants: List<String>.from(json['participants'] as List),
      myName: json['myName'] as String,
      messages: msgsJson
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      platform: ChatPlatform.values[json['platform'] as int],
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        json['importedAt'] as int,
      ),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ChatConversation.fromJsonString(String jsonStr) =>
      ChatConversation.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
