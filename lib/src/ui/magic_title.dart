import 'package:flutter/widgets.dart';

import '../routing/title_manager.dart';

/// A widget that sets the page title while it is mounted.
///
/// On web, this updates the browser tab title. On mobile, it updates the
/// app switcher description. The configured suffix is applied automatically.
class MagicTitle extends StatefulWidget {
  /// The page title to display.
  final String title;

  /// The child widget.
  final Widget child;

  const MagicTitle({required this.title, required this.child, super.key});

  @override
  State<MagicTitle> createState() => _MagicTitleState();
}

class _MagicTitleState extends State<MagicTitle> {
  @override
  void initState() {
    super.initState();
    TitleManager.instance.setOverride(widget.title);
  }

  @override
  void didUpdateWidget(covariant MagicTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      TitleManager.instance.setOverride(widget.title);
    }
  }

  @override
  void dispose() {
    TitleManager.instance.setOverride(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
