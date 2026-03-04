import 'package:flutter/material.dart';
import '../models/chat_conversation.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/import_bottom_sheet.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  List<ConversationSummary> _summaries = [];
  bool _isLoading = true;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    final summaries = await _storage.loadSummaries();
    if (mounted) {
      setState(() {
        _summaries = summaries;
        _isLoading = false;
      });
    }
  }

  void _openImportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ImportBottomSheet(
        storageService: _storage,
        onImportComplete: (conv) {
          Navigator.of(context).pop(); // close bottom sheet
          _loadChats().then((_) => _openChat(conv));
        },
      ),
    );
  }

  Future<void> _openChat(ChatConversation conv) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)));
  }

  Future<void> _openChatById(String id) async {
    final conv = await _storage.loadConversation(id);
    if (conv == null || !mounted) return;
    _openChat(conv);
  }

  Future<void> _deleteChat(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Remove this imported chat from the viewer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.deleteConversation(id);
      _loadChats();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openImportSheet,
        backgroundColor: AppTheme.primaryLight,
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryDark,
      title: const Text(
        'Chat Viewer',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {},
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: _showThemeSettings,
          tooltip: 'Settings',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'CHATS'),
          Tab(text: 'COLLECTIONS'),
          Tab(text: 'UPDATES'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _ChatsTab(
          summaries: _summaries,
          isLoading: _isLoading,
          onTapChat: _openChatById,
          onDeleteChat: _deleteChat,
          onAddChat: _openImportSheet,
        ),
        const _ComingSoonTab(label: 'Collections'),
        const _ComingSoonTab(label: 'Updates'),
      ],
    );
  }

  void _showThemeSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ThemeSettingsSheet(),
    );
  }
}

// ─── Chats Tab ────────────────────────────────────────────────────────────────

class _ChatsTab extends StatelessWidget {
  final List<ConversationSummary> summaries;
  final bool isLoading;
  final void Function(String id) onTapChat;
  final void Function(String id) onDeleteChat;
  final VoidCallback onAddChat;

  const _ChatsTab({
    required this.summaries,
    required this.isLoading,
    required this.onTapChat,
    required this.onDeleteChat,
    required this.onAddChat,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (summaries.isEmpty) {
      return _EmptyState(onAdd: onAddChat);
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        itemCount: summaries.length,
        separatorBuilder: (_, i) => const Divider(
          height: 0,
          indent: 72,
          thickness: 0.5,
          color: AppTheme.divider,
        ),
        itemBuilder: (_, i) {
          final s = summaries[i];
          return _ChatListTile(
            summary: s,
            onTap: () => onTapChat(s.id),
            onDelete: () => onDeleteChat(s.id),
          );
        },
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final ConversationSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatListTile({
    required this.summary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lastTime = summary.importedAt;
    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _Avatar(name: summary.title, platform: summary.platform),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(lastTime),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTimestamp,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${summary.messageCount} messages',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _platformLabel(summary.platform),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _platformLabel(int platform) {
    switch (platform) {
      case 0:
        return 'WhatsApp';
      case 1:
        return 'Instagram';
      case 2:
        return 'Telegram';
      default:
        return 'Chat';
    }
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final int platform;

  const _Avatar({required this.name, required this.platform});

  @override
  Widget build(BuildContext context) {
    const avatarColors = [
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
      Color(0xFFFF7043),
      Color(0xFF66BB6A),
      Color(0xFF26C6DA),
      Color(0xFFD4E157),
    ];
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % avatarColors.length;

    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: avatarColors[idx],
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _platformColor(platform),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(_platformIcon(platform), size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Color _platformColor(int p) {
    switch (p) {
      case 0:
        return const Color(0xFF25D366);
      case 1:
        return const Color(0xFFE1306C);
      case 2:
        return const Color(0xFF0088CC);
      default:
        return Colors.grey;
    }
  }

  IconData _platformIcon(int p) {
    switch (p) {
      case 0:
        return Icons.chat;
      case 1:
        return Icons.camera_alt;
      case 2:
        return Icons.send;
      default:
        return Icons.chat_bubble;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import a chat export file\nto view it beautifully',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Import Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  final String label;
  const _ComingSoonTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 56,
            color: AppTheme.primaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Theme Settings Sheet ─────────────────────────────────────────────────────

class _ThemeSettingsSheet extends StatelessWidget {
  const _ThemeSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Theme',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _ThemeTile(
            label: 'WhatsApp (Default)',
            color: AppTheme.primaryDark,
            isSelected: true,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _ThemeTile(
            label: 'Dark Mode',
            color: const Color(0xFF1A1A2E),
            isSelected: false,
            comingSoon: true,
            onTap: null,
          ),
          const SizedBox(height: 10),
          _ThemeTile(
            label: 'Instagram Vibes',
            color: const Color(0xFFE1306C),
            isSelected: false,
            comingSoon: true,
            onTap: null,
          ),
          const SizedBox(height: 10),
          _ThemeTile(
            label: 'Retro Messenger',
            color: const Color(0xFF1877F2),
            isSelected: false,
            comingSoon: true,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final bool comingSoon;
  final VoidCallback? onTap;

  const _ThemeTile({
    required this.label,
    required this.color,
    required this.isSelected,
    this.comingSoon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: comingSoon ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? color.withValues(alpha: 0.07) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primary,
                  size: 20,
                ),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Soon',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
