import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/widgets/user_avatar.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final List<dynamic> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    await _loadMessages();

    // Listen for new messages in real time
    SocketService().on('new_message', (data) {
      if (!mounted) return;
      setState(() => _messages.add(data));
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    SocketService().off('new_message');
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final resp = await ApiClient.instance.get('/groups/${widget.groupId}/messages');
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(resp.data as List<dynamic>);
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _inputController.clear();

    try {
      await ApiClient.instance.post(
        '/groups/${widget.groupId}/messages',
        data: {'text': text},
      );
      // The socket event `new_message` will append it automatically
    } catch (_) {
      // Restore text if send failed
      _inputController.text = text;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cs.onSurface),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
            ),
            Text(
              'Group Chat',
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.45), fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Divider
          Container(height: 1, color: cs.onSurface.withOpacity(0.06)),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _EmptyChat(cs: cs)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final prev = i > 0 ? _messages[i - 1] : null;
                          return _MessageBubble(
                            message: msg,
                            isMe: (msg['userId'] is Map
                                    ? msg['userId']['_id']
                                    : msg['userId'])
                                .toString() ==
                                _currentUserId,
                            showSenderName: prev == null ||
                                (prev['userId'] is Map
                                    ? prev['userId']['_id']
                                    : prev['userId'])
                                .toString() !=
                                    (msg['userId'] is Map
                                        ? msg['userId']['_id']
                                        : msg['userId'])
                                    .toString(),
                            cs: cs,
                          );
                        },
                      ),
          ),

          // Input bar
          _ChatInput(
            controller: _inputController,
            isSending: _isSending,
            onSend: _sendMessage,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMe;
  final bool showSenderName;
  final ColorScheme cs;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSenderName,
    required this.cs,
  });

  String _formatTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final userMap = message['userId'] is Map ? message['userId'] : null;
    final senderName = (userMap?['name'] as String?) ?? 'Unknown';
    final profileImage = userMap?['profileImage'] as String?;
    final text = message['text'] as String? ?? '';
    final time = _formatTime(message['createdAt'] as String? ?? DateTime.now().toIso8601String());

    return Padding(
      padding: EdgeInsets.only(
        bottom: showSenderName ? 12 : 4,
        top: showSenderName && !isMe ? 8 : 0,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe) ...[
            if (showSenderName)
              UserAvatar(
                name: senderName,
                profileImage: profileImage,
                radius: 16,
                colorScheme: cs,
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderName && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      senderName.split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? cs.primary : cs.surfaceVariant.withOpacity(0.7),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),

          // Spacer for my messages
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final ColorScheme cs;

  const _ChatInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.onSurface.withOpacity(0.08))),
      ),
      child: Row(children: [
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.onSurface.withOpacity(0.08)),
            ),
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.35)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Send button
        GestureDetector(
          onTap: isSending ? null : onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSending ? cs.primary.withOpacity(0.5) : cs.primary,
              shape: BoxShape.circle,
            ),
            child: isSending
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyChat({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('💬', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the conversation!',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
