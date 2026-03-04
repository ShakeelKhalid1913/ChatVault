import 'package:flutter/material.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/date_separator.dart';

class ChatScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _matchedIndices = [];
  int _currentMatchIndex = -1;
  final Map<int, GlobalKey> _matchKeys = {};
  late List<Object> _items;

  bool get _isGroup => widget.conversation.participants.length > 2;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _items = _buildItems(widget.conversation.messages);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // With reverse:true, position.pixels == 0 means we ARE at the bottom
    // (most recent messages). Show FAB when scrolled away from bottom.
    final atBottom = _scrollController.position.pixels <= 200;
    if (!atBottom != _showScrollToBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _matchedIndices = [];
        _currentMatchIndex = -1;
        _matchKeys.clear();
      }
    });
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    _matchKeys.clear();
    final matches = <int>[];
    if (q.isNotEmpty) {
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item is ChatMessage && item.text.toLowerCase().contains(q)) {
          matches.add(i);
          _matchKeys[i] = GlobalKey();
        }
      }
    }
    setState(() {
      _searchQuery = q;
      _matchedIndices = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
    if (matches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch(0));
    }
  }

  void _navigateMatch(int direction) {
    if (_matchedIndices.isEmpty) return;
    final next =
        (_currentMatchIndex + direction + _matchedIndices.length) %
        _matchedIndices.length;
    setState(() => _currentMatchIndex = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch(next));
  }

  void _scrollToMatch(int matchIndex) {
    if (matchIndex < 0 || matchIndex >= _matchedIndices.length) return;
    if (!_scrollController.hasClients) return;

    final itemIdx = _matchedIndices[matchIndex];
    final totalItems = _items.length;

    // With reverse:true ListView:
    // - Scroll position 0 = bottom (most recent messages)
    // - Scroll position maxScrollExtent = top (oldest messages)
    // - itemIdx is the forward index in _items
    // - Items below itemIdx (toward bottom) = totalItems - itemIdx - 1
    // Estimate each message height as 70px (including padding/date separator)
    const estimatedItemHeight = 70.0;
    final itemsBelow = totalItems - itemIdx - 1;
    final targetOffset = itemsBelow * estimatedItemHeight;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final currentMatchItemIndex =
        _currentMatchIndex >= 0 && _matchedIndices.isNotEmpty
        ? _matchedIndices[_currentMatchIndex]
        : -1;

    return Scaffold(
      backgroundColor: AppTheme.chatBackground,
      appBar: _buildAppBar(conv),
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: CustomPaint(painter: _ChatBackgroundPainter()),
          ),

          // Messages
          ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              if (item is DateTime) {
                return DateSeparator(date: item);
              }
              final msg = item as ChatMessage;
              final isSentByMe = msg.sender == conv.myName;
              final isMatch = _matchKeys.containsKey(i);
              final isCurrentMatch = i == currentMatchItemIndex;
              return ChatBubble(
                key: isMatch ? _matchKeys[i] : null,
                message: msg,
                isSentByMe: isSentByMe,
                showSenderName: _isGroup,
                highlightQuery: _searchQuery.isEmpty ? null : _searchQuery,
                isCurrentResult: isCurrentMatch,
              );
            },
          ),

          // Scroll to bottom button
          if (_showScrollToBottom)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryDark,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatConversation conv) {
    // ── Search mode ──
    if (_isSearching) {
      return AppBar(
        backgroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _toggleSearch,
          tooltip: 'Cancel search',
        ),
        titleSpacing: 4,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search in chat…',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          if (_matchedIndices.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${_currentMatchIndex + 1} / ${_matchedIndices.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            )
          else if (_searchQuery.isNotEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  'No results',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
            onPressed: _matchedIndices.isNotEmpty
                ? () => _navigateMatch(-1)
                : null,
            tooltip: 'Previous',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            onPressed: _matchedIndices.isNotEmpty
                ? () => _navigateMatch(1)
                : null,
            tooltip: 'Next',
          ),
        ],
      );
    }

    // ── Normal mode ──
    final others = conv.participants.where((p) => p != conv.myName).toList();
    final displayName = others.isEmpty ? conv.title : others.join(', ');
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    return AppBar(
      backgroundColor: AppTheme.primaryDark,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.teal.shade300,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${conv.messageCount} messages',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // IconButton(
        //   icon: const Icon(Icons.search, color: Colors.white),
        //   onPressed: _toggleSearch,
        //   tooltip: 'Search',
        // ),
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Colors.white),
          onPressed: () {},
          tooltip: 'Video call',
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Colors.white),
          onPressed: () {},
          tooltip: 'Call',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (val) {
            if (val == 'info') _showChatInfo();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'info', child: Text('Chat info')),
          ],
        ),
      ],
    );
  }

  /// Builds a flat list of either [DateTime] separators or [ChatMessage]s.
  /// The list is returned in REVERSE chronological order because the
  /// ListView uses reverse:true — index 0 is the most recent item.
  List<Object> _buildItems(List<ChatMessage> msgs) {
    if (msgs.isEmpty) return [];

    final forward = <Object>[];
    DateTime? lastDate;

    for (final msg in msgs) {
      final msgDate = DateTime(
        msg.timestamp.year,
        msg.timestamp.month,
        msg.timestamp.day,
      );
      if (lastDate == null || msgDate != lastDate) {
        forward.add(msgDate);
        lastDate = msgDate;
      }
      forward.add(msg);
    }
    return forward.reversed.toList();
  }

  void _showChatInfo() {
    final conv = widget.conversation;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chat Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('Platform', 'WhatsApp'),
            _InfoRow('Messages', '${conv.messageCount}'),
            _InfoRow('Participants', conv.participants.join(', ')),
            _InfoRow('Your name', conv.myName),
            _InfoRow('Imported', _fmtDate(conv.importedAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ─── Chat Input Bar (decorative, read-only viewer) ───────────────────────────

class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F2F5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Read-only viewer',
                  style: TextStyle(color: AppTheme.textTimestamp, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Subtle background pattern ───────────────────────────────────────────────

class _ChatBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simple subtle dot pattern like WhatsApp
    final paint = Paint()
      ..color = const Color(0xFFCBBFB5).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.5;

    for (double y = 0; y < size.height; y += spacing) {
      for (
        double x = (y ~/ spacing).isEven ? 0 : spacing / 2;
        x < size.width;
        x += spacing
      ) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ChatBackgroundPainter old) => false;
}
