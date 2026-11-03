import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// The panel of the `/welcome/tips` bottom sheet.
///
/// An overlay route builds a frame only, so this view draws its own surface
/// and closes itself through [MagicRoute.back], which asks the route's
/// dismiss guard (none here) like a scrim tap does.
class WelcomeSheetView extends StatelessWidget {
  /// Creates the [WelcomeSheetView].
  const WelcomeSheetView({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        w-full max-w-[480px] mx-auto p-6 flex flex-col gap-3
        rounded-t-2xl bg-white dark:bg-gray-800
      ''',
      children: [
        WText(
          'Quick tip',
          className: 'text-lg font-bold text-gray-900 dark:text-white',
        ),
        WText(
          'This sheet is a route: it has its own URL and Back closes it.',
          className: 'text-sm text-gray-500 dark:text-gray-400',
        ),
        const WSpacer(className: 'h-2'),
        WButton(
          onTap: MagicRoute.back,
          className: '''
            px-4 py-2 rounded-lg bg-primary text-white
            hover:bg-primary-700 text-center
          ''',
          child: WText('Close', className: 'text-sm font-medium text-white'),
        ),
      ],
    );
  }
}
