import 'package:flutter/material.dart';

Future<T?> showQuasiFullscreenModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double heightFactor = 0.96,
  bool showDragHandle = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (sheetContext) => _QuasiFullscreenModalContainer(
      heightFactor: heightFactor,
      child: builder(sheetContext),
    ),
  );
}

class QuasiFullscreenModalScaffold extends StatelessWidget {
  const QuasiFullscreenModalScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _QuasiFullscreenModalContainer extends StatelessWidget {
  const _QuasiFullscreenModalContainer({
    required this.heightFactor,
    required this.child,
  });

  final double heightFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final insetBottom = MediaQuery.of(context).viewInsets.bottom;
    final outline = Theme.of(context).dividerColor.withValues(alpha: 0.4);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: insetBottom),
      child: FractionallySizedBox(
        heightFactor: heightFactor,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: outline)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
