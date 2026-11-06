import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// The panel of the `/welcome/tips` overlay route.
///
/// An overlay route builds a frame only, so this view draws its own surface
/// and closes itself through [MagicRoute.back], which asks the route's
/// dismiss guard (none here) like a scrim tap does.
///
/// The frame is a bottom sheet on a narrow window and a centred dialog from
/// 1024 px, picked by `MagicRoute.useOverlayPresentation` in
/// `RouteServiceProvider`. The two frames hand a panel different room (a sheet
/// is as wide as the screen, a dialog route fills it), so the panel asks which
/// one it sits in: a dialog route is a [RawDialogRoute], a sheet is not.
class WelcomeSheetView extends StatelessWidget {
  /// Creates the [WelcomeSheetView].
  const WelcomeSheetView({super.key});

  @override
  Widget build(BuildContext context) {
    final inDialog = ModalRoute.of(context) is RawDialogRoute;

    final panel = WDiv(
      className:
          '''
        w-full max-w-[480px] p-6 flex flex-col gap-3
        ${inDialog ? 'rounded-2xl shadow-xl' : 'rounded-t-2xl'}
        bg-white dark:bg-gray-800
      ''',
      children: [
        WText(
          'Quick tip',
          className: 'text-lg font-bold text-gray-900 dark:text-white',
        ),
        WText(
          'This panel is a route: it has its own URL and Back closes it.',
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

    // Both frames hand the panel loose constraints. `mx-auto` is left out on
    // purpose: it takes all the room on both axes.
    if (inDialog) {
      // A dialog route gives the panel the whole screen, so it centres on both
      // axes. Unlike a sheet, the route has no Material above it, and text
      // without one is drawn with the debug fallback style (yellow underline),
      // so the panel brings a transparent one, around the card only so the
      // scrim around it still takes a tap.
      return Center(
        child: Material(type: MaterialType.transparency, child: panel),
      );
    }

    // A sheet sits on the bottom edge by itself, so it only centres across and
    // keeps its content's height.
    return Center(heightFactor: 1, child: panel);
  }
}
