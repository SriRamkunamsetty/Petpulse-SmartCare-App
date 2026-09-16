import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// `.pp-sheet-backdrop` / `.pp-sheet` — a bottom sheet with a drag handle,
/// shown via [showPpSheet] so it matches the prototype's look without
/// pulling in a custom route transition.
Future<T?> showPpSheet<T>(BuildContext context,
    {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: PpColors.neutral900.withValues(alpha: 0.45),
    builder: (context) => PpSheetContainer(child: builder(context)),
  );
}

class PpSheetContainer extends StatelessWidget {
  const PpSheetContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      decoration: const BoxDecoration(
        color: PpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 14, top: 6),
              decoration: BoxDecoration(
                color: PpColors.neutral400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
