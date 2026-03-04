import '../models/chat_message.dart';

/// Parses a WhatsApp exported .txt chat file.
///
/// Supported format (both 12-hour with am/pm):
///   DD/MM/YYYY, HH:MM am/pm - Sender: Message
///   DD/MM/YYYY, HH:MM am/pm - System message
class WhatsAppParser {
  // Matches the beginning of any message line
  // Group 1: date  e.g. "16/11/2022"
  // Group 2: time  e.g. "11:12 pm"  or  "11:12\u202fpm"  (narrow no-break space)
  static final _lineRegex = RegExp(
    r'^\[?(\d{1,2}\/\d{1,2}\/\d{4}),[\s\u202f](\d{1,2}:\d{2}(?::\d{2})?[\s\u202f]?[AaPp][Mm])\]?[\s-]+(.+)$',
  );

  // Matches sender vs message: "Sender Name: Rest of message"
  // The body part is optional — empty-body lines are call/ring events.
  static final _senderRegex = RegExp(r'^([^:]{1,60}):\s*(.*)$', dotAll: true);

  /// Parse the full content of a WhatsApp .txt export.
  /// Returns a list of [ChatMessage] objects.
  static List<ChatMessage> parse(String content) {
    final lines = content.split('\n');
    final messages = <ChatMessage>[];
    int idCounter = 0;

    String? currentDate;
    String? currentTime;
    String? currentSender;
    String currentText = '';
    bool hasCurrentMessage = false;

    void flushMessage() {
      if (!hasCurrentMessage) return;
      final ts = _parseTimestamp(currentDate!, currentTime!);
      if (ts == null) {
        hasCurrentMessage = false;
        return;
      }
      final rawText = currentText.trim();
      const editedMarker = '<This message was edited>';
      final isEdited = rawText.endsWith(editedMarker);
      final text = isEdited
          ? rawText
                .substring(0, rawText.length - editedMarker.length)
                .trimRight()
          : rawText;
      final type = _detectType(currentSender, text);
      messages.add(
        ChatMessage(
          id: '${idCounter++}',
          sender: currentSender,
          text: text,
          timestamp: ts,
          type: type,
          isEdited: isEdited,
        ),
      );
      hasCurrentMessage = false;
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final match = _lineRegex.firstMatch(line);

      if (match != null) {
        flushMessage();
        currentDate = match.group(1)!;
        currentTime = match.group(2)!;
        final content = match.group(3)!;

        final senderMatch = _senderRegex.firstMatch(content);
        if (senderMatch != null) {
          currentSender = senderMatch.group(1)!.trim();
          currentText = senderMatch.group(2)!;
        } else {
          currentSender = null;
          currentText = content;
        }
        hasCurrentMessage = true;
      } else if (hasCurrentMessage) {
        // Continuation of multi-line message
        currentText += '\n$line';
      }
    }
    flushMessage();

    return messages;
  }

  /// Extract unique participant names (excluding null / system)
  static List<String> extractParticipants(List<ChatMessage> messages) {
    final seen = <String>{};
    for (final m in messages) {
      if (m.sender != null && m.sender!.isNotEmpty) {
        seen.add(m.sender!);
      }
    }
    return seen.toList()..sort();
  }

  static MessageType _detectType(String? sender, String text) {
    if (sender == null) {
      // System message
      final lower = text.toLowerCase();
      if (lower.contains('missed') &&
          (lower.contains('call') ||
              lower.contains('voice call') ||
              lower.contains('video call'))) {
        return MessageType.missedCall;
      }
      return MessageType.system;
    }
    // Empty body = WhatsApp call event (the other side called / rang)
    if (text.trim().isEmpty) return MessageType.callEvent;

    final lower = text.toLowerCase().trim();
    if (lower == '<media omitted>' ||
        lower == 'image omitted' ||
        lower == 'video omitted' ||
        lower == 'audio omitted' ||
        lower == 'sticker omitted' ||
        lower == 'document omitted' ||
        lower == 'gif omitted') {
      return MessageType.media;
    }
    if (lower.startsWith('missed voice call') ||
        lower.startsWith('missed video call')) {
      return MessageType.missedCall;
    }
    if (lower.startsWith('poll:') || text.contains('\nOPTION:')) {
      return MessageType.poll;
    }
    if (lower == 'this message was deleted' ||
        lower == 'you deleted this message') {
      return MessageType.deletedMessage;
    }
    return MessageType.text;
  }

  static DateTime? _parseTimestamp(String date, String time) {
    try {
      final dateParts = date.split('/');
      if (dateParts.length < 3) return null;
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      // Normalize time: remove narrow no-break space, regular space, lower-case
      final t = time.replaceAll('\u202f', ' ').trim().toLowerCase();
      final isPm = t.endsWith('pm');
      final timePart = t.replaceAll(RegExp(r'[apm\s]'), '');
      final parts = timePart.split(':');
      if (parts.isEmpty) return null;

      var hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
