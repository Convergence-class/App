import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';
import 'package:emotion_app/data/chat/local_chat_store.dart';
import 'package:emotion_app/data/session/app_session.dart';
import 'package:emotion_app/shared/widgets/app_widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final api = BackendApi();
  final store = LocalChatStore();
  final controller = TextEditingController();
  final scrollController = ScrollController();

  bool loading = true;
  bool sending = false;
  bool consent = false;
  String? error;
  LocalChatConversation? active;
  List<LocalChatConversation> conversations = [];

  List<Map<String, dynamic>> get messages => active?.messages ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final consentResult = await _ignore(api.getConsent());
      final data = asMap(consentResult?['data']);
      consent = asBool(
        data?['chatbot_optin'],
        AppSession.instance.chatbotOptIn,
      );
      await AppSession.instance.setChatbotOptIn(consent);
      conversations = await store.load();
      active = conversations.isNotEmpty ? conversations.first : _createDraft();
      if (!mounted) return;
      setState(() {});
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>?> _ignore(
    Future<Map<String, dynamic>> future,
  ) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _agreeChatbot() async {
    setState(() => loading = true);
    try {
      await api.saveConsent(
        dataCollection: true,
        notification: true,
        chatbotOptin: true,
      );
      await AppSession.instance.setChatbotOptIn(true);
      if (!mounted) return;
      setState(() {
        consent = true;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (!consent) {
      setState(() => error = 'AI 챗봇 이용 동의가 필요합니다.');
      return;
    }
    if (text.isEmpty || sending) return;

    final current = active ?? _createDraft();
    final requestHistory = current.messages
        .where(
          (message) => message['role'] == 'user' || message['role'] == 'model',
        )
        .map(
          (message) => {
            'role': message['role'].toString(),
            'content': message['content'].toString(),
          },
        )
        .toList();

    final now = DateTime.now();
    final userMessage = {
      'role': 'user',
      'content': text,
      'created_at': now.toIso8601String(),
    };
    final nextMessages = [...current.messages, userMessage];
    final titled = current.title == '새 대화'
        ? current.copyWith(
            title: _titleFrom(text),
            messages: nextMessages,
            updatedAt: now,
          )
        : current.copyWith(messages: nextMessages, updatedAt: now);

    controller.clear();
    setState(() {
      sending = true;
      error = null;
      active = titled;
      _replaceConversation(titled);
    });
    await store.upsert(titled);
    _scrollToBottom();

    try {
      final response = await api.sendChatMessage(text, history: requestHistory);
      final reply = response['reply']?.toString() ?? '';
      final replyTime = DateTime.now();
      final updated = titled.copyWith(
        updatedAt: replyTime,
        messages: [
          ...titled.messages,
          {
            'role': 'model',
            'content': reply,
            'created_at': replyTime.toIso8601String(),
          },
        ],
      );
      await store.upsert(updated);
      if (!mounted) return;
      setState(() {
        active = updated;
        _replaceConversation(updated);
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _newChat() {
    setState(() {
      active = _createDraft();
      error = null;
    });
    controller.clear();
  }

  void _selectConversation(LocalChatConversation conversation) {
    setState(() {
      active = conversation;
      error = null;
    });
    Navigator.pop(context);
    _scrollToBottom();
  }

  Future<void> _deleteConversation(LocalChatConversation conversation) async {
    await store.delete(conversation.id);
    conversations = await store.load();
    if (!mounted) return;
    setState(() {
      if (active?.id == conversation.id) {
        active = conversations.isNotEmpty
            ? conversations.first
            : _createDraft();
      }
    });
  }

  void _replaceConversation(LocalChatConversation conversation) {
    final index = conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index == -1) {
      conversations.insert(0, conversation);
    } else {
      conversations[index] = conversation;
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  LocalChatConversation _createDraft() {
    final now = DateTime.now();
    return LocalChatConversation(
      id: now.microsecondsSinceEpoch.toString(),
      title: '새 대화',
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
  }

  String _titleFrom(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= 18) return trimmed;
    return '${trimmed.substring(0, 18)}...';
  }

  void _openConversationSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                '대화 기록',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            if (conversations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '저장된 대화가 아직 없어요.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
              ),
            ...conversations.map(
              (conversation) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${conversation.messages.length}개 메시지 · ${_dateLabel(conversation.updatedAt)}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _selectConversation(conversation),
                trailing: IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    await _deleteConversation(conversation);
                    if (context.mounted) Navigator.pop(context);
                    _openConversationSheet();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final shownMessages = messages;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.blueSoft,
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 16,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    active?.title ?? 'AI 챗봇',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '대화 기록',
                  onPressed: _openConversationSheet,
                  icon: const Icon(Icons.history_rounded, size: 20),
                ),
                IconButton(
                  tooltip: '새 채팅',
                  onPressed: consent ? _newChat : null,
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                ),
              ],
            ),
          ),
          if (!consent) _ConsentCard(onAgree: _agreeChatbot),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: shownMessages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                    itemCount: shownMessages.length,
                    itemBuilder: (context, index) {
                      final message = shownMessages[index];
                      final role = message['role']?.toString() ?? 'model';
                      final content = message['content']?.toString() ?? '';
                      final time = _timeLabel(
                        message['created_at']?.toString(),
                      );
                      if (role == 'user') {
                        return _UserMessage(text: content, time: time);
                      }
                      return _BotMessage(text: content, time: time);
                    },
                  ),
          ),
          _ChatInput(
            controller: controller,
            sending: sending,
            enabled: consent,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  String _timeLabel(String? raw) {
    final value = DateTime.tryParse(raw ?? '');
    if (value == null) return '';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _dateLabel(DateTime value) {
    return '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '새 대화를 시작해보세요.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.onAgree});

  final VoidCallback onAgree;

  @override
  Widget build(BuildContext context) {
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '챗봇 이용 동의가 필요해요',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI 챗봇 대화를 사용하려면 먼저 이용 동의가 필요합니다.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          YellowButton(label: '동의하고 대화 시작', onPressed: onAgree),
        ],
      ),
    );
  }
}

class _BotMessage extends StatelessWidget {
  const _BotMessage({required this.text, required this.time});

  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.blueSoft,
            child: Icon(
              Icons.smart_toy_outlined,
              size: 16,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.text, required this.time});

  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled && !sending,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: enabled
                    ? (sending ? '답변을 기다리는 중...' : '마음을 편하게 적어보세요')
                    : '챗봇 이용 동의가 필요합니다',
                hintStyle: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xffeadbc8),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: enabled ? AppColors.amber : AppColors.line,
            child: IconButton(
              onPressed: enabled && !sending ? onSend : null,
              icon: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
