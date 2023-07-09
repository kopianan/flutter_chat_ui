import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import 'create_message.dart';

class Local extends StatefulWidget {
  final String userId;
  final Dio dio;

  const Local({super.key, required this.userId, required this.dio});

  @override
  LocalState createState() => LocalState();
}

class LocalState extends State<Local> {
  final _chatController = InMemoryChatController();

  @override
  Future<void> dispose() async {
    try {
      // Wrapped in Future.delayed as per this issue: https://github.com/flutter/flutter/issues/64935
      Future.delayed(Duration.zero, () async {
        await _chatController.dispose();
      });
    } catch (e) {
      debugPrint('Error disposing chat controller: $e');
    }
    super.dispose();
  }

  void _addItem() async {
    final randomSenderId = Random().nextInt(2) == 0 ? 'sender1' : 'sender2';

    final message = await createMessage(randomSenderId, widget.dio);

    if (mounted) {
      await _chatController.insert(message);
    }
  }

  void _removeItem(Message item) async {
    await _chatController.remove(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Chat(
        chatController: _chatController,
        userId: widget.userId,
        onMessageTap: _removeItem,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
      persistentFooterButtons: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Go back'),
        ),
        TextButton(
          onPressed: () {
            _chatController.set([]);
          },
          child: const Text('Clear all messages'),
        ),
      ],
    );
  }
}
