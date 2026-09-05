import 'package:flutter/widgets.dart';

import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/utils/platform_utils.dart';

/// Desktop windows keep mouse/keyboard dialogs even when resized below the
/// large-screen breakpoint. Layouts still measure their own available space.
bool useDesktopWorkspaceLayout(BuildContext context) =>
    PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context);
