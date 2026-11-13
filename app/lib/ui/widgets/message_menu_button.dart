import 'package:flutter/material.dart';

import '../../messages/app_message.dart';
import '../theme.dart';

/// 顶部消息按钮：点开后在按钮下方展开消息下拉列表。
///
/// 列表里一条消息一行；需要处理的消息在正文后带一个操作按钮。
/// 点整条消息只记为已读，点操作按钮才会回调首页做跳转。
class MessageMenuButton extends StatefulWidget {
  const MessageMenuButton({
    super.key,
    required this.messages,
    required this.readIds,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onAction,
  });

  /// 当前消息，按时间倒序。
  final List<AppMessage> messages;

  /// 已读消息 id；由首页持有。
  final Set<String> readIds;

  /// 单条已读回调。
  final ValueChanged<String> onMarkRead;

  /// 全部已读回调。
  final VoidCallback onMarkAllRead;

  /// 点消息上的操作按钮时回调，例如「去计划」。
  final ValueChanged<AppMessage> onAction;

  @override
  State<MessageMenuButton> createState() => _MessageMenuButtonState();
}

class _MessageMenuButtonState extends State<MessageMenuButton> {
  final _controller = MenuController();

  /// 未读条数，用来显示角标和顶部小字。
  int get _unreadCount => widget.messages
      .where((message) => !widget.readIds.contains(message.id))
      .length;

  /// 收起下拉列表。
  void _close() {
    if (_controller.isOpen) {
      _controller.close();
    }
  }

  /// 记下一条已读；不收起列表，方便连着看完。
  void _markRead(AppMessage message) {
    if (widget.readIds.contains(message.id)) {
      return;
    }
    widget.onMarkRead(message.id);
  }

  /// 执行消息上的操作：先记为已读，收起列表，再交给首页。
  void _runAction(AppMessage message) {
    _markRead(message);
    _close();
    widget.onAction(message);
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      // 下拉面板宽 360，按钮约 40，向左偏移让它贴着按钮右边缘展开。
      alignmentOffset: const Offset(-320, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(paperSurface),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: paperLine),
          ),
        ),
      ),
      menuChildren: [_panel(context)],
      builder: (context, controller, child) {
        return IconButton(
          key: const Key('top_messages'),
          tooltip: '消息',
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: Badge(
            isLabelVisible: _unreadCount > 0,
            backgroundColor: paperOchre,
            label: Text('$_unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }

  /// 消息下拉面板：标题栏 + 消息列表。
  Widget _panel(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: [
                Text('消息', style: text.titleMedium),
                const SizedBox(width: 8),
                if (_unreadCount > 0)
                  Text('$_unreadCount 条未读', style: text.bodySmall),
                const Spacer(),
                TextButton(
                  key: const Key('message_mark_all_read'),
                  onPressed: _unreadCount == 0 ? null : widget.onMarkAllRead,
                  child: const Text('全部已读'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: paperLine),
          if (widget.messages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('还没有消息。', style: text.bodySmall),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.messages.length; i++) ...[
                      _tile(context, widget.messages[i]),
                      if (i != widget.messages.length - 1)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: paperLine,
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 一条消息：图标、标题、时间、正文，末尾按需放操作按钮。
  Widget _tile(BuildContext context, AppMessage message) {
    final text = Theme.of(context).textTheme;
    final unread = !widget.readIds.contains(message.id);
    final icon = switch (message.kind) {
      AppMessageKind.planReminder => Icons.event_note_outlined,
      AppMessageKind.system => Icons.campaign_outlined,
    };
    return InkWell(
      key: Key('message_item_${message.id}'),
      onTap: () => _markRead(message),
      child: ColoredBox(
        color: unread ? paperOchre.withValues(alpha: 0.05) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: paperOchre),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.title,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: paperOchre,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          _formatTime(message.createdAt),
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(message.body, style: text.bodySmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          message.kind.label,
                          style: text.bodySmall?.copyWith(
                            fontSize: 11,
                            letterSpacing: 1,
                            color: paperStone,
                          ),
                        ),
                        const Spacer(),
                        if (message.actionLabel != null)
                          TextButton(
                            key: Key('message_action_${message.id}'),
                            style: TextButton.styleFrom(
                              foregroundColor: paperOchre,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _runAction(message),
                            child: Text(message.actionLabel!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 今天只显示时分，更早的显示月日与时分。
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        time.year == now.year && time.month == now.month && time.day == now.day;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return sameDay ? '$hh:$mm' : '${time.month}/${time.day} $hh:$mm';
  }
}
