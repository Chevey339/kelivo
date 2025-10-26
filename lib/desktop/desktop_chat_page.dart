import 'package:flutter/material.dart';
import '../features/home/pages/home_page.dart';

/// Desktop chat page entry.
/// For phase 1, reuse the tablet layout that already exists in HomePage when the width is large.
/// Later we can extract the tablet branch into a dedicated desktop layout under this folder.
class DesktopChatPage extends StatelessWidget {
  const DesktopChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse existing chat experience (tablet branch) without modifying mobile implementation.
    return const HomePage();
  }
}

