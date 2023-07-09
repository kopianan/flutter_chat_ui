import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'create_message.dart';

class Api extends StatefulWidget {
  final String userId;
  final List<Message> initialMessages;
  final Dio dio;

  const Api({
    super.key,
    required this.userId,
    required this.initialMessages,
    required this.dio,
  });

  @override
  ApiState createState() => ApiState();
}

class ApiState extends State<Api> {
  late WebSocketChannel _channel;
  late StreamSubscription<dynamic> _channelStream;
  late ChatController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController(messages: widget.initialMessages);

    _connectToWs();
  }

  @override
  Future<void> dispose() async {
    try {
      // Wrapped in Future.delayed as per this issue: https://github.com/flutter/flutter/issues/64935
      Future.delayed(Duration.zero, () async {
        await _channel.sink.close();
      });
    } catch (e) {
      debugPrint('Error closing WebSocket sink: $e');
    }
    try {
      Future.delayed(Duration.zero, () async {
        await _channelStream.cancel();
      });
    } catch (e) {
      debugPrint('Error canceling WebSocket stream: $e');
    }
    try {
      Future.delayed(Duration.zero, () async {
        await _chatController.dispose();
      });
    } catch (e) {
      debugPrint('Error disposing chat controller: $e');
    }
    super.dispose();
  }

  void _connectToWs() async {
    final uri = Uri(
      scheme: 'wss',
      host: 'whatever.diamanthq.dev',
      path: 'ws',
      queryParameters: {'senderId': widget.userId},
    );

    _channel = WebSocketChannel.connect(uri);

    await _channel.ready;

    _channelStream = _channel.stream.listen((message) {
      try {
        final json = jsonDecode(message);
        if (json['msg'] != null) {
          final message = Message.fromJson(json['msg']);
          if (mounted) {
            if (json['op'] == 'new') {
              _chatController.insert(message);
            } else if (json['op'] == 'del') {
              _chatController.remove(message);
            }
          }
        }
      } catch (error) {
        _showInfo('Error: ${error.toString()}');
      }
    });
  }

  void _addItem() async {
    final message = await createMessage(widget.userId, widget.dio);

    if (mounted) {
      await _chatController.insert(message);
    }

    try {
      final response = await widget.dio.post<Map<String, dynamic>>(
        'https://whatever.diamanthq.dev/message',
        data: message.toJson(),
      );

      if (mounted) {
        // Make sure to get the updated message
        // (width and height might have been set by the image message widget)
        final possiblyUpdatedMessage = _chatController.messages.firstWhere(
          (element) => element.id == message.id,
          orElse: () => message,
        );
        await _chatController.update(
          possiblyUpdatedMessage,
          possiblyUpdatedMessage.copyWith(id: response.data!['id']),
        );
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  void _removeItem(Message item) async {
    await _chatController.remove(item);

    try {
      await widget.dio.delete<void>(
        'https://whatever.diamanthq.dev/message',
        data: {'id': item.id},
      );
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  Future<void> _showInfo(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Info'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
            widget.dio
                .post('https://whatever.diamanthq.dev/message-flush')
                .then((response) {
              if (response.statusCode == 200) {
                if (mounted) {
                  _chatController.set([]);
                  _showInfo('All messages cleared');
                }
              } else {
                _showInfo('Error: ${response.statusCode}');
              }
            }).catchError((error) {
              _showInfo('Error: ${error.toString()}');
            });
          },
          child: const Text('Clear all messages'),
        ),
      ],
    );
  }
}
