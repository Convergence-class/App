import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';
import 'package:emotion_app/data/api/api_helpers.dart';
import 'package:emotion_app/data/api/backend_api.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final api = BackendApi();
  final controller = TextEditingController();
  final scrollController = ScrollController();
  bool loading = true;
  bool sending = false;
  String? error;
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.getChatHistory(limit: 50);
      if (!mounted) return;
      setState(() => messages = asMapList(response['data']));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    controller.clear();
    setState(() {
      sending = true;
      error = null;
      messages.add({
        'role': 'user',
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final response = await api.sendChatMessage(text);
      final reply = response['reply']?.toString() ?? '';
      if (!mounted) return;
      setState(
        () => messages.add({
          'role': 'model',
          'content': reply,
          'created_at': DateTime.now().toIso8601String(),
        }),
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
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
    final visibleMessages = messages.isEmpty
        ? const [
            {
              'role': 'model',
              'content': 'Hello. Write anything on your mind.',
              'created_at': '',
            },
          ]
        : messages;

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
                const Text(
                  'AI Chatbot',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  onPressed: loading ? null : _loadHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.mutedText,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    loading
                        ? 'Loading history'
                        : 'History count: ${messages.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              itemCount: visibleMessages.length,
              itemBuilder: (context, index) {
                final message = visibleMessages[index];
                final role = message['role']?.toString() ?? 'model';
                final content = message['content']?.toString() ?? '';
                final time = _timeLabel(message['created_at']?.toString());
                if (role == 'user') {
                  return _UserMessage(text: content, time: time);
                }
                return _BotMessage(text: content, time: time);
              },
            ),
          ),
          _ChatInput(controller: controller, sending: sending, onSend: _send),
        ],
      ),
    );
  }

  String _timeLabel(String? raw) {
    final value = DateTime.tryParse(raw ?? '');
    if (value == null) return '';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
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
              enabled: !sending,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: sending ? 'Waiting for reply...' : 'Type a message',
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
            backgroundColor: AppColors.amber,
            child: IconButton(
              onPressed: sending ? null : onSend,
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
