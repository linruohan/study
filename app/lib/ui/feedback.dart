import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// 当前显示的轻提示；新的提示会顶掉旧的，避免右下角叠成一堆。
OverlayEntry? _activeToast;

/// 成功提示：右下角绿色轻提示，宽度跟随文字，不遮挡页面操作。
void showSuccessToast(BuildContext context, String message) {
  _showToast(context, message, color: const Color(0xFF3F7A4F), icon: Icons.check);
}

/// 中性提示：用于引导或非成功非失败的信息。
void showInfoToast(BuildContext context, String message) {
  _showToast(context, message, color: paperInk, icon: Icons.info_outline);
}

/// 失败的统一弹窗：标题说明哪一步失败，正文给出具体原因。
Future<void> showFailureDialog(
  BuildContext context, {
  String title = '操作失败',
  required String reason,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      key: const Key('failure_dialog'),
      title: Text(title),
      content: Text(reason.isEmpty ? '未知原因，请稍后再试。' : reason),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 右下角浮动提示的通用实现。
///
/// 用 Overlay + IgnorePointer，不带遮罩，也不会挡住下面的点击；
/// 文字短时容器自然收窄，长时最多 420 宽再换行。
void _showToast(
  BuildContext context,
  String message, {
  required Color color,
  required IconData icon,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  final previous = _activeToast;
  if (previous != null && previous.mounted) {
    previous.remove();
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastHost(
      message: message,
      color: color,
      icon: icon,
      onDismiss: () {
        if (entry.mounted) {
          entry.remove();
        }
        if (identical(_activeToast, entry)) {
          _activeToast = null;
        }
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

/// 轻提示本体：淡入、停留、淡出后自动移除。
class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  var _opacity = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _opacity = 1);
      }
    });
    _timer = Timer(const Duration(milliseconds: 2200), () async {
      if (!mounted) {
        return;
      }
      setState(() => _opacity = 0);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
