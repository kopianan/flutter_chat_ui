import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:provider/provider.dart';

import 'utils/typedefs.dart';

class ChatMessage extends StatefulWidget {
  final Animation<double> animation;
  final Message message;
  final OnMessageTapCallback? onMessageTap;
  final bool? isRemoved;

  const ChatMessage({
    super.key,
    required this.animation,
    required this.message,
    this.onMessageTap,
    this.isRemoved,
  });

  @override
  State<ChatMessage> createState() => ChatMessageState();
}

class ChatMessageState extends State<ChatMessage> {
  late StreamSubscription<ChatOperation>? _operationsSubscription;
  late Message _updatedMessage;

  @override
  void initState() {
    super.initState();

    _updatedMessage = widget.message;

    if (widget.isRemoved == true) {
      _operationsSubscription = null;
    } else {
      final chatController =
          Provider.of<ChatController>(context, listen: false);
      _operationsSubscription = chatController.operationsStream.listen((event) {
        switch (event.type) {
          case ChatOperationType.update:
            assert(
              event.oldMessage != null,
              'Old message must be provided when updating a message.',
            );
            assert(
              event.message != null,
              'Message must be provided when updating a message.',
            );
            if (_updatedMessage == event.oldMessage) {
              setState(() {
                _updatedMessage = event.message!;
              });
            }
          default:
            break;
        }
      });
    }
  }

  @override
  Future<void> dispose() async {
    try {
      // Wrapped in Future.delayed as per this issue: https://github.com/flutter/flutter/issues/64935
      Future.delayed(Duration.zero, () async {
        await _operationsSubscription?.cancel();
      });
    } catch (e) {
      debugPrint('Error canceling operations subscription: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<String>();
    final curvedAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.linearToEaseOut,
    );

    return GestureDetector(
      onTap: () => widget.onMessageTap?.call(_updatedMessage),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: SizeTransition(
          sizeFactor: curvedAnimation,
          child: ScaleTransition(
            scale: curvedAnimation,
            alignment: _updatedMessage.senderId == userId
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Align(
              alignment: _updatedMessage.senderId == userId
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: _updatedMessage is TextMessage
                  ? FlyerChatTextMessage(
                      message: _updatedMessage as TextMessage,
                    )
                  : FlyerChatImageMessage(
                      message: _updatedMessage as ImageMessage,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
