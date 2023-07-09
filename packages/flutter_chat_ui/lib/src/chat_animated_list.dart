import 'dart:async';

import 'package:diffutil_dart/diffutil.dart' as diffutil;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';

class ChatAnimatedList extends StatefulWidget {
  const ChatAnimatedList({
    super.key,
    required this.itemBuilder,
    this.insertAnimationDuration = const Duration(milliseconds: 250),
    this.removeAnimationDuration = const Duration(milliseconds: 250),
    this.scrollToEndAnimationDuration = const Duration(milliseconds: 250),
  });

  final Widget Function(
    BuildContext,
    Animation<double>,
    Message, {
    bool? isRemoved,
  }) itemBuilder;
  final Duration insertAnimationDuration;
  final Duration removeAnimationDuration;
  final Duration scrollToEndAnimationDuration;

  @override
  ChatAnimatedListState createState() => ChatAnimatedListState();
}

class ChatAnimatedListState extends State<ChatAnimatedList> {
  final GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();
  late ChatController _chatController;
  late List<Message> _oldList;
  late StreamSubscription<ChatOperation> _operationsSubscription;
  final _scrollController = ScrollController();
  bool _userHasScrolled = false;
  bool _needsInitialScrollPositionAdjustment = true;
  String _lastInsertedMessageId = '';

  @override
  void initState() {
    super.initState();
    _chatController = Provider.of<ChatController>(context, listen: false);
    _oldList = List.from(_chatController.messages);
    _operationsSubscription = _chatController.operationsStream.listen((event) {
      switch (event.type) {
        case ChatOperationType.insert:
          assert(
            event.index != null,
            'Index must be provided when inserting a message.',
          );
          assert(
            event.message != null,
            'Message must be provided when inserting a message.',
          );
          _onInserted(event.index!, event.message!);
          _oldList = List.from(_chatController.messages);
          break;
        case ChatOperationType.remove:
          assert(
            event.index != null,
            'Index must be provided when removing a message.',
          );
          assert(
            event.message != null,
            'Message must be provided when removing a message.',
          );
          _onRemoved(event.index!, event.message!);
          _oldList = List.from(_chatController.messages);
          break;
        case ChatOperationType.set:
          final newList = _chatController.messages;

          final updates = diffutil
              .calculateDiff<Message>(
                MessageListDiff(_oldList, newList),
              )
              .getUpdatesWithData();

          for (final update in updates) {
            _onDiffUpdate(update);
          }

          _oldList = List.from(newList);
          break;
        default:
          break;
      }
    });
  }

  @override
  Future<void> dispose() async {
    try {
      // Wrapped in Future.delayed as per this issue: https://github.com/flutter/flutter/issues/64935
      Future.delayed(Duration.zero, () async {
        await _operationsSubscription.cancel();
      });
    } catch (e) {
      debugPrint('Error canceling operations subscription: $e');
    }
    try {
      _scrollController.dispose();
    } catch (e) {
      debugPrint('Error disposing scroll controller: $e');
    }
    super.dispose();
  }

  void _initialScrollToEnd() async {
    // Delay the scroll to the end animation so new message is painted, otherwise
    // maxScrollExtent is not yet updated and the animation might not work.
    await Future.delayed(widget.insertAnimationDuration);

    if (!_scrollController.hasClients || !mounted) return;

    if (_scrollController.offset < _scrollController.position.maxScrollExtent) {
      if (widget.scrollToEndAnimationDuration == Duration.zero) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.scrollToEndAnimationDuration,
          curve: Curves.linearToEaseOut,
        );
      }
    }
  }

  void _subsequentScrollToEnd(Message data) async {
    final userId = Provider.of<String>(context, listen: false);

    // In this case we only want to scroll to the bottom if user has not scrolled up
    // or if the message is sent by the current user.
    if (data.id == _lastInsertedMessageId &&
        _scrollController.offset < _scrollController.position.maxScrollExtent &&
        (userId == data.senderId || !_userHasScrolled)) {
      if (widget.scrollToEndAnimationDuration == Duration.zero) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.scrollToEndAnimationDuration,
          curve: Curves.linearToEaseOut,
        );
      }

      if (!_scrollController.hasClients || !mounted) return;

      // Because of the issue I have opened here https://github.com/flutter/flutter/issues/129768
      // we need an additional jump to the end. Sometimes Flutter
      // will not scroll to the very end. Sometimes it will not scroll to the
      // very end even with this, so this is something that needs to be
      // addressed by the Flutter team.
      //
      // Additionally here we have a check for the message id, because
      // if new message arrives in the meantime it will trigger another
      // scroll to the end animation, making this logic redundant.
      if (data.id == _lastInsertedMessageId &&
          _scrollController.offset <
              _scrollController.position.maxScrollExtent &&
          (userId == data.senderId || !_userHasScrolled)) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _scrollToEnd(Message data) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients || !mounted) return;

        // We need this condition because if scroll view is not yet scrollable,
        // we want to wait for the insert animation to finish before scrolling to the end.
        if (_scrollController.position.maxScrollExtent == 0) {
          // Scroll view is not yet scrollable, scroll to the end if
          // new message makes it scrollable.
          _initialScrollToEnd();
        } else {
          _subsequentScrollToEnd(data);
        }
      },
    );
  }

  void _onInserted(final int position, final Message data) {
    final userId = Provider.of<String>(context, listen: false);

    // There is a scroll notification listener the controls the `_userHasScrolled` variable.
    // However, when a new message is sent by the current user we want to
    // set `_userHasScrolled` to false so that the scroll animation is triggered.
    //
    // Also, if for some reason `_userHasScrolled` is true and the user is not at the bottom of the list,
    // set `_userHasScrolled` to false so that the scroll animation is triggered.
    if (userId == data.senderId ||
        (_userHasScrolled == true &&
            _scrollController.offset >=
                _scrollController.position.maxScrollExtent)) {
      _userHasScrolled = false;
    }

    _listKey.currentState!.insertItem(
      position,
      // We are only animating items when scroll view is not yet scrollable,
      // otherwise we just insert the item without animation.
      // (animation is replaced with scroll to bottom animation)
      duration: _scrollController.position.maxScrollExtent == 0
          ? widget.insertAnimationDuration
          : Duration.zero,
    );

    // Used later to trigger scroll to end only for the last inserted message.
    _lastInsertedMessageId = data.id;

    _scrollToEnd(data);
  }

  void _onRemoved(final int position, final Message data) {
    _listKey.currentState!.removeItem(
      position,
      (context, animation) => widget.itemBuilder(
        context,
        animation,
        data,
        isRemoved: true,
      ),
      duration: widget.removeAnimationDuration,
    );
  }

  void _onChanged(int position) {
    _listKey.currentState!.removeItem(
      position,
      (context, animation) => const SizedBox.shrink(),
      duration: Duration.zero,
    );
    _listKey.currentState!.insertItem(
      position,
      duration: Duration.zero,
    );
  }

  void _onDiffUpdate(diffutil.DataDiffUpdate<Message> update) {
    update.when<void>(
      insert: (pos, data) => _onInserted(pos, data),
      remove: (pos, data) => _onRemoved(pos, data),
      change: (pos, oldData, newData) => _onChanged(pos),
      move: (_, __, ___) => throw UnimplementedError('unused'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: (notification) {
        // Handle initial scroll to bottom so you see latest messages
        if (notification is ScrollMetricsNotification) {
          // Here we check if maxScrollExtent is not 0, so we need to jump to the end,
          // otherwise we don't need to adjust the initial scroll position.
          if (_needsInitialScrollPositionAdjustment &&
              notification.metrics.maxScrollExtent != 0) {
            _scrollController.jumpTo(notification.metrics.maxScrollExtent);
          } else {
            _needsInitialScrollPositionAdjustment = false;
          }

          // If we jumped to the end, we check if pixels are equal to maxScrollExtent,
          // cause sometimes Flutter will under or overscroll. We will repeat the jump
          // util pixels are equal to maxScrollExtent, setting adjustment to false.
          // Visually it looks like 1 jump, so it is fine.
          if (_needsInitialScrollPositionAdjustment) {
            if (notification.metrics.pixels ==
                notification.metrics.maxScrollExtent) {
              _needsInitialScrollPositionAdjustment = false;
            } else {
              _scrollController.jumpTo(notification.metrics.maxScrollExtent);
            }
          }
        }

        if (notification is UserScrollNotification) {
          // When user scrolls up, save it to `_userHasScrolled`
          if (notification.direction == ScrollDirection.forward) {
            _userHasScrolled = true;
          } else {
            // When user overscolls to the bottom or stays idle at the bottom, set `_userHasScrolled` to false
            if (notification.metrics.pixels ==
                notification.metrics.maxScrollExtent) {
              _userHasScrolled = false;
            }
          }
        }

        // Allow other listeners to get the notification
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAnimatedList(
            key: _listKey,
            initialItemCount: _chatController.messages.length,
            itemBuilder: (
              BuildContext context,
              int index,
              Animation<double> animation,
            ) =>
                widget.itemBuilder(
              context,
              animation,
              _chatController.messages[index],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageListDiff extends diffutil.ListDiffDelegate<Message> {
  MessageListDiff(super.oldList, super.newList);

  @override
  bool areContentsTheSame(int oldItemPosition, int newItemPosition) =>
      equalityChecker(oldList[oldItemPosition], newList[newItemPosition]);

  @override
  bool areItemsTheSame(int oldItemPosition, int newItemPosition) =>
      oldList[oldItemPosition].id == newList[newItemPosition].id;
}
