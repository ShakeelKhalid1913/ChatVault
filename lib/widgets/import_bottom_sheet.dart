import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../services/storage_service.dart';
import '../services/whatsapp_parser.dart';
import '../theme/app_theme.dart';

// Top-level function required by compute()
List<ChatMessage> _isolateParse(String content) =>
    WhatsAppParser.parse(content);

enum _ImportStep { platformSelect, whatsAppInstructions, participantSelect }

class ImportBottomSheet extends StatefulWidget {
  final StorageService storageService;
  final void Function(ChatConversation) onImportComplete;

  const ImportBottomSheet({
    super.key,
    required this.storageService,
    required this.onImportComplete,
  });

  @override
  State<ImportBottomSheet> createState() => _ImportBottomSheetState();
}

class _ImportBottomSheetState extends State<ImportBottomSheet>
    with SingleTickerProviderStateMixin {
  _ImportStep _step = _ImportStep.platformSelect;
  bool _isLoading = false;
  String? _errorMessage;

  // WhatsApp import state
  List<ChatMessage> _parsedMessages = [];
  List<String> _participants = [];
  String? _selectedSelf;
  String? _fileName;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Steps ───────────────────────────────────────────────────────────────

  void _onWhatsAppTap() {
    setState(() {
      _step = _ImportStep.whatsAppInstructions;
      _errorMessage = null;
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'zip'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;
      String content;

      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        content = String.fromCharCodes(file.bytes!);
      } else {
        throw Exception('Cannot read file');
      }

      final messages = await compute(_isolateParse, content);
      if (messages.isEmpty) {
        throw Exception(
          'No messages found. Make sure you selected a WhatsApp chat export .txt file.',
        );
      }

      final participants = WhatsAppParser.extractParticipants(messages);

      setState(() {
        _parsedMessages = messages;
        _participants = participants;
        _fileName = file.name;
        _step = _ImportStep.participantSelect;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _generateChatUi() async {
    if (_selectedSelf == null) {
      setState(() => _errorMessage = 'Please select which participant is you.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final otherParticipant = _participants.firstWhere(
        (p) => p != _selectedSelf,
        orElse: () => _selectedSelf!,
      );
      final title = otherParticipant == _selectedSelf
          ? _selectedSelf!
          : otherParticipant;

      final conv = ChatConversation(
        id: const Uuid().v4(),
        title: title,
        participants: _participants,
        myName: _selectedSelf!,
        messages: _parsedMessages,
        platform: ChatPlatform.whatsapp,
        importedAt: DateTime.now(),
      );

      await widget.storageService.saveConversation(conv);
      if (mounted) widget.onImportComplete(conv);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save: $e';
        _isLoading = false;
      });
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == _ImportStep.platformSelect ? 0.55 : 0.85,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _DragHandle(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildBody(scrollController),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ScrollController sc) {
    switch (_step) {
      case _ImportStep.platformSelect:
        return _PlatformSelectView(
          scrollController: sc,
          onWhatsAppTap: _onWhatsAppTap,
        );
      case _ImportStep.whatsAppInstructions:
        return _WhatsAppImportView(
          scrollController: sc,
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          fileName: _fileName,
          onPickFile: _pickFile,
          onBack: () => setState(() {
            _step = _ImportStep.platformSelect;
            _errorMessage = null;
          }),
        );
      case _ImportStep.participantSelect:
        return _ParticipantSelectView(
          scrollController: sc,
          participants: _participants,
          selectedSelf: _selectedSelf,
          fileName: _fileName ?? '',
          messageCount: _parsedMessages.length,
          errorMessage: _errorMessage,
          isLoading: _isLoading,
          onSelect: (p) => setState(() => _selectedSelf = p),
          onGenerate: _generateChatUi,
          onBack: () => setState(() {
            _step = _ImportStep.whatsAppInstructions;
            _errorMessage = null;
          }),
        );
    }
  }
}

// ─── Sub-views ────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 10),
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
      const SizedBox(height: 4),
    ],
  );
}

// ── Platform Select ──

class _PlatformSelectView extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onWhatsAppTap;

  const _PlatformSelectView({
    required this.scrollController,
    required this.onWhatsAppTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'Import Chat',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the platform to import from',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        _PlatformTile(
          icon: Icons.chat,
          iconColor: const Color(0xFF25D366),
          label: 'WhatsApp',
          subtitle: 'Import .txt export',
          enabled: true,
          onTap: onWhatsAppTap,
        ),
        const SizedBox(height: 12),
        _PlatformTile(
          icon: Icons.camera_alt,
          iconColor: const Color(0xFFE1306C),
          label: 'Instagram',
          subtitle: 'Coming soon',
          enabled: false,
          onTap: null,
        ),
        const SizedBox(height: 12),
        _PlatformTile(
          icon: Icons.send,
          iconColor: const Color(0xFF0088CC),
          label: 'Telegram',
          subtitle: 'Coming soon',
          enabled: false,
          onTap: null,
        ),
        const SizedBox(height: 12),
        _PlatformTile(
          icon: Icons.facebook,
          iconColor: const Color(0xFF1877F2),
          label: 'Facebook Messenger',
          subtitle: 'Coming soon',
          enabled: false,
          onTap: null,
        ),
        const SizedBox(height: 12),
        _PlatformTile(
          icon: Icons.sms,
          iconColor: const Color(0xFF4E73DF),
          label: 'SMS / iMessage',
          subtitle: 'Coming soon',
          enabled: false,
          onTap: null,
        ),
      ],
    );
  }
}

class _PlatformTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _PlatformTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled
                  ? iconColor.withValues(alpha: 0.4)
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(14),
            color: enabled
                ? iconColor.withValues(alpha: 0.04)
                : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!enabled)
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
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: iconColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── WhatsApp Import ──

class _WhatsAppImportView extends StatelessWidget {
  final ScrollController scrollController;
  final bool isLoading;
  final String? errorMessage;
  final String? fileName;
  final VoidCallback onPickFile;
  final VoidCallback onBack;

  const _WhatsAppImportView({
    required this.scrollController,
    required this.isLoading,
    required this.errorMessage,
    required this.fileName,
    required this.onPickFile,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              color: AppTheme.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Text(
              'Import WhatsApp Chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Instructions card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF25D366).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'How to export from WhatsApp',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Step(n: 1, text: 'Open a chat in WhatsApp'),
              _Step(n: 2, text: 'Tap ⋮ (three dots) → More → Export chat'),
              _Step(n: 3, text: 'Choose "Without media"'),
              _Step(n: 4, text: 'Save or share the .txt file to your device'),
              _Step(n: 5, text: 'Come back here and tap "Select File" below'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (fileName != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onPickFile,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_file),
            label: Text(isLoading ? 'Parsing…' : 'Select .txt File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$n',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Participant Select ──

class _ParticipantSelectView extends StatelessWidget {
  final ScrollController scrollController;
  final List<String> participants;
  final String? selectedSelf;
  final String fileName;
  final int messageCount;
  final String? errorMessage;
  final bool isLoading;
  final void Function(String) onSelect;
  final VoidCallback onGenerate;
  final VoidCallback onBack;

  const _ParticipantSelectView({
    required this.scrollController,
    required this.participants,
    required this.selectedSelf,
    required this.fileName,
    required this.messageCount,
    required this.errorMessage,
    required this.isLoading,
    required this.onSelect,
    required this.onGenerate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              color: AppTheme.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Text(
              'Who are you?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$messageCount messages parsed from $fileName',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select your name so your messages appear on the right side.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        ...participants.map(
          (p) => _ParticipantTile(
            name: p,
            isSelected: p == selectedSelf,
            onTap: () => onSelect(p),
          ),
        ),
        const SizedBox(height: 8),
        if (errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
        ],
        AnimatedOpacity(
          opacity: selectedSelf != null ? 1 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (selectedSelf != null && !isLoading)
                  ? onGenerate
                  : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: Text(isLoading ? 'Generating…' : 'Generate Chat UI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ParticipantTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.07)
              : Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isSelected
                  ? AppTheme.primary
                  : Colors.grey.shade200,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
