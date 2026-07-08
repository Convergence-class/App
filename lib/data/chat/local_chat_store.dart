import 'dart:convert';

import 'package:emotion_app/data/session/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalChatConversation {
  const LocalChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> messages;

  LocalChatConversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? messages,
  }) {
    return LocalChatConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'messages': messages,
  };

  static LocalChatConversation fromJson(Map<String, dynamic> json) {
    return LocalChatConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '새 대화',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      messages: (json['messages'] is List)
          ? (json['messages'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[],
    );
  }
}

class LocalChatStore {
  static const _keyPrefix = 'local_chat_conversations';

  String get _key {
    final session = AppSession.instance;
    final owner = session.userId?.trim().isNotEmpty == true
        ? session.userId!.trim()
        : session.email?.trim().toLowerCase();
    return '$_keyPrefix.${owner ?? 'guest'}';
  }

  Future<List<LocalChatConversation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              LocalChatConversation.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveAll(List<LocalChatConversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = conversations
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _key,
      jsonEncode(normalized.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> upsert(LocalChatConversation conversation) async {
    final conversations = await load();
    final index = conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index == -1) {
      conversations.insert(0, conversation);
    } else {
      conversations[index] = conversation;
    }
    await saveAll(conversations);
  }

  Future<void> delete(String id) async {
    final conversations = await load();
    conversations.removeWhere((item) => item.id == id);
    await saveAll(conversations);
  }
}
