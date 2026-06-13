import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';
import '../../../core/services/migration/migration_service.dart';
import '../../../l10n/app_localizations.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  MigrationProgress? _progress;
  MigrationResult? _result;
  bool _running = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startMigration() async {
    if (_running) return;
    setState(() {
      _running = true;
      _result = null;
      _progress = null;
    });

    final result = await MigrationService.run(
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _running = false;
    });

    if (result.success) {
      // Wait briefly so user sees completion message
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Restart.restartApp();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: 64, color: _iconColor),
                  const SizedBox(height: 24),
                  Text(
                    _title(l10n),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _description(l10n),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF8E8E93),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_progress != null) ...[
                    const SizedBox(height: 32),
                    _buildProgressBar(),
                  ],
                  if (_result != null && !_result!.success) ...[
                    const SizedBox(height: 24),
                    Text(
                      '${l10n.migrateStepError}: ${_result!.error}',
                      style: const TextStyle(color: Color(0xFFFF453A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      label: l10n.migrateRetry,
                      onTap: _startMigration,
                    ),
                  ],
                  if (!_running && _result == null) ...[
                    const SizedBox(height: 32),
                    _buildButton(
                      label: l10n.migrateButtonStart,
                      onTap: _startMigration,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _progress!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.progress,
            backgroundColor: const Color(0xFF3A3A3C),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          progress.message,
          style: const TextStyle(fontSize: 14, color: Color(0xFFEBEBF5)),
          textAlign: TextAlign.center,
        ),
        if (progress.currentConversation != null &&
            progress.totalConversations != null &&
            progress.totalConversations! > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppLocalizations.of(context)!.migrateConversationCount(
                progress.currentConversation!,
                progress.totalConversations!,
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          ),
      ],
    );
  }

  Widget _buildButton({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  IconData get _icon {
    if (_result?.success == true) return Icons.check_circle_outline;
    if (_result != null && !_result!.success) return Icons.error_outline;
    if (_running) return Icons.hourglass_top;
    return Icons.storage_outlined;
  }

  Color get _iconColor {
    if (_result?.success == true) return const Color(0xFF30D158);
    if (_result != null && !_result!.success) return const Color(0xFFFF453A);
    return const Color(0xFF0A84FF);
  }

  String _title(AppLocalizations l10n) {
    if (_result?.success == true) return l10n.migrateStepComplete;
    if (_result != null && !_result!.success) return l10n.migrateStepError;
    return l10n.migrateTitle;
  }

  String _description(AppLocalizations l10n) {
    if (_result?.success == true) return '';
    if (_result != null && !_result!.success) return '';
    return l10n.migrateDescription;
  }
}
