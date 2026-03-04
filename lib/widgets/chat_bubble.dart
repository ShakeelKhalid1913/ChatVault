import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;
  final bool showSenderName;
  final String? highlightQuery;
  final bool isCurrentResult;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSentByMe,
    this.showSenderName = false,
    this.highlightQuery,
    this.isCurrentResult = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check call types first — missedCall is also flagged isSystem so order matters
    if (message.type == MessageType.missedCall) {
      return _CallTile(message: message, isSentByMe: isSentByMe, missed: true);
    }
    if (message.type == MessageType.callEvent) {
      return _CallTile(message: message, isSentByMe: isSentByMe, missed: false);
    }
    if (message.isSystem) return _SystemBubble(message: message);

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isSentByMe ? 60 : 12,
          right: isSentByMe ? 12 : 60,
        ),
        child: CustomPaint(
          painter: _BubbleTailPainter(
            isSentByMe: isSentByMe,
            color: isSentByMe ? AppTheme.sentBubble : AppTheme.receivedBubble,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrentResult
                  ? const Color(0xFFFFF176)
                  : (isSentByMe
                        ? AppTheme.sentBubble
                        : AppTheme.receivedBubble),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(8),
                topRight: const Radius.circular(8),
                bottomLeft: Radius.circular(isSentByMe ? 8 : 2),
                bottomRight: Radius.circular(isSentByMe ? 2 : 8),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x15000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSenderName && !isSentByMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.sender ?? '',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _senderColor(message.sender ?? ''),
                      ),
                    ),
                  ),
                if (message.type == MessageType.media)
                  _MediaPlaceholder(isSentByMe: isSentByMe)
                else if (message.type == MessageType.poll)
                  _PollBubble(text: message.text)
                else if (message.type == MessageType.deletedMessage)
                  _DeletedMessage()
                else
                  _RichMessageText(
                    text: message.text,
                    highlightQuery: highlightQuery,
                    isCurrentResult: isCurrentResult,
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.isEdited) ...[
                      const Text(
                        'Edited',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textTimestamp,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTimestamp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Color _senderColor(String name) {
    const colors = [
      Color(0xFF00BCD4),
      Color(0xFF009688),
      Color(0xFF4CAF50),
      Color(0xFF8BC34A),
      Color(0xFFFF9800),
      Color(0xFFFF5722),
      Color(0xFF9C27B0),
      Color(0xFF2196F3),
    ];
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[idx];
  }
}

class _RichMessageText extends StatelessWidget {
  final String text;
  final String? highlightQuery;
  final bool isCurrentResult;

  const _RichMessageText({
    required this.text,
    this.highlightQuery,
    this.isCurrentResult = false,
  });

  /// Builds spans with WhatsApp formatting (*bold*, _italic_, ~strike~)
  /// and optionally highlights [query] occurrences within each segment.
  static List<InlineSpan> _buildSpans(
    String text,
    String? query,
    bool isCurrent,
  ) {
    final pattern = RegExp(r'(\*[^*\n]+\*|_[^_\n]+_|~[^~\n]+~)');
    final spans = <InlineSpan>[];
    int last = 0;
    final q = (query ?? '').toLowerCase();

    // Adds plain or highlighted text with an optional base formatting style.
    void addSegment(String segment, TextStyle? base) {
      if (segment.isEmpty) return;
      if (q.isEmpty) {
        spans.add(TextSpan(text: segment, style: base));
        return;
      }
      final lower = segment.toLowerCase();
      int s = 0;
      while (true) {
        final idx = lower.indexOf(q, s);
        if (idx == -1) {
          if (s < segment.length) {
            spans.add(TextSpan(text: segment.substring(s), style: base));
          }
          break;
        }
        if (idx > s) {
          spans.add(TextSpan(text: segment.substring(s, idx), style: base));
        }
        spans.add(
          TextSpan(
            text: segment.substring(idx, idx + q.length),
            style: TextStyle(
              fontWeight: base?.fontWeight,
              fontStyle: base?.fontStyle,
              decoration: base?.decoration,
              backgroundColor: isCurrent
                  ? const Color(0xFFF9A825)
                  : const Color(0xFFFFE082),
              color: AppTheme.textPrimary,
            ),
          ),
        );
        s = idx + q.length;
      }
    }

    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        addSegment(text.substring(last, match.start), null);
      }
      final raw = match.group(0)!;
      final inner = raw.substring(1, raw.length - 1);
      if (raw.startsWith('*')) {
        addSegment(inner, const TextStyle(fontWeight: FontWeight.bold));
      } else if (raw.startsWith('_')) {
        addSegment(inner, const TextStyle(fontStyle: FontStyle.italic));
      } else {
        addSegment(
          inner,
          const TextStyle(decoration: TextDecoration.lineThrough),
        );
      }
      last = match.end;
    }
    if (last < text.length) addSegment(text.substring(last), null);
    if (spans.isEmpty) addSegment(text, null);
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: _buildSpans(text, highlightQuery, isCurrentResult),
        style: const TextStyle(
          fontSize: 15,
          color: AppTheme.textPrimary,
          height: 1.35,
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final bool isSentByMe;
  const _MediaPlaceholder({required this.isSentByMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 160,
      decoration: BoxDecoration(
        color: isSentByMe ? const Color(0xFFC8E6C9) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo, size: 48, color: Color(0xFF90A4AE)),
          SizedBox(height: 6),
          Text(
            'Media omitted',
            style: TextStyle(fontSize: 12, color: Color(0xFF90A4AE)),
          ),
        ],
      ),
    );
  }
}

class _PollBubble extends StatelessWidget {
  final String text;
  const _PollBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final question = lines.isNotEmpty
        ? lines[0].replaceFirst('POLL:', '').trim()
        : '';
    final options = lines
        .where((l) => l.startsWith('OPTION:'))
        .map((l) => l.replaceFirst('OPTION:', '').trim())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.poll, size: 14, color: AppTheme.primary),
            SizedBox(width: 4),
            Text(
              'POLL',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        ...options.map(
          (opt) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.radio_button_unchecked,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    opt,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeletedMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block, size: 14, color: AppTheme.textTimestamp),
        SizedBox(width: 4),
        Text(
          'This message was deleted',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textTimestamp,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final ChatMessage message;
  const _SystemBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.systemMessage,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4A4A4A),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;

  /// true = missed call (red), false = call event (green)
  final bool missed;

  const _CallTile({
    required this.message,
    required this.isSentByMe,
    required this.missed,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = message.text.toLowerCase().contains('video');

    final IconData icon;
    final Color iconColor;
    final String label;

    if (missed) {
      icon = isVideo ? Icons.videocam_off_outlined : Icons.phone_missed;
      iconColor = Colors.red;
      label = message.text.isNotEmpty
          ? message.text
          : (isVideo ? 'Missed video call' : 'Missed voice call');
    } else {
      // callEvent — empty body, the sender rang the other person
      icon = isVideo ? Icons.videocam_outlined : Icons.call_outlined;
      iconColor = const Color(0xFF25D366);
      label = isSentByMe ? 'You called' : 'Called you';
    }

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isSentByMe ? 60 : 12,
          right: isSentByMe ? 12 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSentByMe ? AppTheme.sentBubble : AppTheme.receivedBubble,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x15000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _fmt(message.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTimestamp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}

// Simple painter for the tail of a bubble
class _BubbleTailPainter extends CustomPainter {
  final bool isSentByMe;
  final Color color;
  const _BubbleTailPainter({required this.isSentByMe, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // We rely purely on the Container's borderRadius for the bubble shape;
    // the tail is implicit from different corner radii. No additional paint needed.
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => false;
}
