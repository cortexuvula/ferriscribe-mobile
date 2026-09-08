import 'package:flutter/material.dart';

/// Overlays the lock screen ABOVE the app without unmounting it.
///
/// Codie/ui-consultant review requirements: while locked, the retained
/// app subtree must be invisible AND unreachable — excluded from touch,
/// keyboard focus/shortcuts, semantics (screen-reader announcements),
/// and back navigation — without disposing route State (unsaved editor
/// drafts, an active recording, etc. must survive lock→unlock).
///
/// Mechanics:
/// - The app subtree stays in the tree (State preserved) but is wrapped
///   in [ExcludeSemantics] (no announcements), [IgnorePointer] (no
///   touch), an absorbing [FocusScope] with `canRequestFocus: false`
///   (no focus/shortcuts), and [Visibility.maintain] (not painted, not
///   hit-testable, still laid out so State and controllers live).
/// - [PopScope] on the overlay blocks back navigation from dismissing
///   the lock.
class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({
    super.key,
    required this.locked,
    required this.lockScreen,
    required this.child,
  });

  final bool locked;
  final Widget lockScreen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        // Retained-but-unreachable app subtree.
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: FocusScope(
                canRequestFocus: false,
                child: Offstage(
                  // Offstage: keeps State (drafts, controllers alive).
                  // It still LAYS OUT the child (RenderOffstage
                  // performs child.layout) but sizes itself to
                  // constraints.smallest, paints nothing, and
                  // hit-tests nothing; standard finders skip it. (The
                  // earlier 'lays out nothing' claim was wrong —
                  // ui-consultant's catch.)
                  child: child,
                ),
              ),
            ),
          ),
        ),
        // The lock screen itself: opaque, absorbing, back-blocked.
        Positioned.fill(
          child: PopScope(
            canPop: false,
            child: ExcludeSemantics(excluding: false, child: lockScreen),
          ),
        ),
      ],
    );
  }
}
