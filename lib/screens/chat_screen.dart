import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fetch() {
    final ride = ref.read(rideProvider).ride;
    if (ride != null) {
      ref.read(rideProvider.notifier).fetchMessages(ride['id'] as int);
    }
  }

  void _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;

    final ride = ref.read(rideProvider).ride;
    if (ride == null) return;

    _controller.clear();
    
    try {
      await ref.read(rideProvider.notifier).sendMessage(ride['id'] as int, body);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(rideProvider).messages;
    final user = ref.watch(authProvider).user;
    final userId = user?['id'] as int?;

    ref.listen(rideProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final isMe = m['sender_id'] == userId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : null,
                        bottomLeft: !isMe ? const Radius.circular(0) : null,
                      ),
                    ),
                    child: Text(
                      m['body'],
                      style: TextStyle(
                        color: isMe ? Theme.of(context).colorScheme.onPrimary : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
