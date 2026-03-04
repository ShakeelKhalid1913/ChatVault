import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_conversation.dart';

// Top-level function required by compute()
ChatConversation _isolateDeserialize(String jsonStr) =>
    ChatConversation.fromJsonString(jsonStr);

/// Persists and loads [ChatConversation] objects.
///
/// Metadata (id, title, participants, importedAt, messageCount, platform, myName)
/// is stored as a JSON list in SharedPreferences.
///
/// Full conversation data (including messages) is stored as individual JSON
/// files in the app documents directory.
class StorageService {
  static const _metaKey = 'chat_conversations_meta';

  // ─── Public API ──────────────────────────────────────────────────────────

  Future<void> saveConversation(ChatConversation conv) async {
    await _writeFile(conv.id, conv.toJsonString());
    await _upsertMeta(ConversationMeta.fromConversation(conv));
  }

  Future<List<ConversationMeta>> loadAllMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ConversationMeta.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
  }

  Future<ChatConversation?> loadConversation(String id) async {
    final content = await _readFile(id);
    if (content == null) return null;
    // Deserialize on a background isolate — big chats have thousands of
    // messages and jsonDecode on the main thread freezes the UI.
    return compute(_isolateDeserialize, content);
  }

  Future<void> deleteConversation(String id) async {
    await _deleteFile(id);
    final prefs = await SharedPreferences.getInstance();
    final metas = await loadAllMeta();
    metas.removeWhere((m) => m.id == id);
    await prefs.setString(
      _metaKey,
      jsonEncode(metas.map((m) => m.toJson()).toList()),
    );
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  Future<Directory> get _dir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/chat_viewer');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _writeFile(String id, String content) async {
    final dir = await _dir;
    final file = File('${dir.path}/$id.json');
    await file.writeAsString(content, flush: true);
  }

  Future<String?> _readFile(String id) async {
    try {
      final dir = await _dir;
      final file = File('${dir.path}/$id.json');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteFile(String id) async {
    try {
      final dir = await _dir;
      final file = File('${dir.path}/$id.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _upsertMeta(ConversationMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    final metas = await loadAllMeta();
    metas.removeWhere((m) => m.id == meta.id);
    metas.add(meta);
    await prefs.setString(
      _metaKey,
      jsonEncode(metas.map((m) => m.toJson()).toList()),
    );
  }
}

class ConversationMeta {
  final String id;
  final String title;
  final String myName;
  final List<String> participants;
  final int messageCount;
  final int platform;
  final DateTime importedAt;

  const ConversationMeta({
    required this.id,
    required this.title,
    required this.myName,
    required this.participants,
    required this.messageCount,
    required this.platform,
    required this.importedAt,
  });

  factory ConversationMeta.fromConversation(ChatConversation c) =>
      ConversationMeta(
        id: c.id,
        title: c.title,
        myName: c.myName,
        participants: c.participants,
        messageCount: c.messageCount,
        platform: c.platform.index,
        importedAt: c.importedAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'myName': myName,
    'participants': participants,
    'messageCount': messageCount,
    'platform': platform,
    'importedAt': importedAt.millisecondsSinceEpoch,
  };

  factory ConversationMeta.fromJson(Map<String, dynamic> json) =>
      ConversationMeta(
        id: json['id'] as String,
        title: json['title'] as String,
        myName: json['myName'] as String? ?? '',
        participants: List<String>.from(json['participants'] as List? ?? []),
        messageCount: json['messageCount'] as int? ?? 0,
        platform: json['platform'] as int? ?? 0,
        importedAt: DateTime.fromMillisecondsSinceEpoch(
          json['importedAt'] as int,
        ),
      );
}

// a simple DTO to pass back to the UI
class ConversationSummary {
  final String id;
  final String title;
  final String myName;
  final List<String> participants;
  final int messageCount;
  final int platform;
  final DateTime importedAt;

  const ConversationSummary({
    required this.id,
    required this.title,
    required this.myName,
    required this.participants,
    required this.messageCount,
    required this.platform,
    required this.importedAt,
  });

  factory ConversationSummary.fromMeta(ConversationMeta m) =>
      ConversationSummary(
        id: m.id,
        title: m.title,
        myName: m.myName,
        participants: m.participants,
        messageCount: m.messageCount,
        platform: m.platform,
        importedAt: m.importedAt,
      );
}

extension StorageServiceExt on StorageService {
  Future<List<ConversationSummary>> loadSummaries() async {
    final metas = await loadAllMeta();
    return metas.map(ConversationSummary.fromMeta).toList();
  }
}
