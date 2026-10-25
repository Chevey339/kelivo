import 'dart:async';
import 'dart:io';

/// Stable tool-facing failures. Native exception text stays out of the wire
/// contract; recovery advice must never suggest repeating an unknown mutation.
class BrowserFailure implements Exception {
  const BrowserFailure(
    this.code,
    this.message,
    this.nextAction, {
    this.recoverable = true,
    this.outcomeUnknown = false,
  });
  final String code, message, nextAction;
  final bool recoverable, outcomeUnknown;

  static BrowserFailure loadTimeout(String stage) => BrowserFailure(
    'browser_load_timeout',
    'The page did not reach $stage before the navigation deadline.',
    'Inspect the current page, then wait for a specific element or navigate elsewhere.',
  );

  static const renderer = BrowserFailure(
    'browser_renderer_terminated',
    'The page renderer stopped. The tab can be reopened with the same tab_id.',
    'Open or reload this tab. Inspect the page before repeating any previous action.',
    outcomeUnknown: true,
  );

  factory BrowserFailure.from(Object error) {
    if (error is BrowserFailure) return error;
    if (error is FormatException || error is ArgumentError) {
      return const BrowserFailure(
        'browser_invalid_arguments',
        'The browser arguments are invalid.',
        'Check the tool schema and provide valid arguments.',
        recoverable: false,
      );
    }
    if (error is FileSystemException) {
      return const BrowserFailure(
        'browser_workspace_file_error',
        'The workspace file could not be read or written.',
        'Check the bound workspace, relative path, permissions and available disk space.',
      );
    }
    if (error is TimeoutException) {
      return const BrowserFailure(
        'browser_wait_timeout',
        'The requested page condition was not reached before the deadline.',
        'Inspect the current page before choosing another wait or navigation.',
      );
    }
    final raw = error is StateError
        ? error.message.toString()
        : error.toString();
    final code = RegExp(
      r'(browser_[a-z_]+|stale_ref|element_[a-z_]+|input_[a-z_]+|option_[a-z_]+|ambiguous_[a-z_]+|snapshot_budget_too_small|coordinates_outside_viewport)',
    ).firstMatch(raw)?.group(0);
    return switch (code) {
      'browser_agent_disabled' => const BrowserFailure(
        'browser_agent_disabled',
        'Browser control is disabled.',
        'Ask the user to enable browser control.',
        recoverable: false,
      ),
      'browser_human_control' => const BrowserFailure(
        'browser_human_control',
        'The user has taken control of the browser.',
        'Wait for the user to allow continuation.',
        recoverable: false,
      ),
      'browser_action_timeout_outcome_unknown' ||
      'browser_action_cancelled_outcome_unknown' => BrowserFailure(
        code!,
        'The previous operation did not return a confirmed outcome.',
        'Ask the user to inspect the page and allow continuation. Do not repeat the operation automatically.',
        recoverable: false,
        outcomeUnknown: true,
      ),
      'browser_renderer_terminated' => renderer,
      'stale_ref' => const BrowserFailure(
        'stale_ref',
        'The target element or document changed.',
        'Take a new snapshot and choose the current target.',
      ),
      'element_not_visible' || 'element_covered' => BrowserFailure(
        code!,
        'The target is hidden or covered.',
        'Inspect the page and dismiss the obstruction; do not click through it.',
      ),
      'input_value_rejected' || 'input_target_replaced' => BrowserFailure(
        code!,
        'The field did not retain the requested input.',
        'Inspect its current value and validation rules before retrying.',
      ),
      'browser_session_tab_limit' => const BrowserFailure(
        'browser_session_tab_limit',
        'This conversation has reached its tab limit.',
        'Use list_tabs, then reuse an existing tab with open or close one before creating another.',
      ),
      'element_not_found' => const BrowserFailure(
        'element_not_found',
        'The target element was not found.',
        'Inspect the current page and choose a current ref or unique selector.',
      ),
      'browser_tab_closed' ||
      'browser_tab_not_found' ||
      'browser_no_active_tab' => BrowserFailure(
        code!,
        'The requested tab is not available.',
        'Use list_tabs to choose an owned tab, or open a new tab.',
      ),
      final String value when value.startsWith('browser_workspace') =>
        BrowserFailure(
          value,
          'The requested workspace file is unavailable or outside the current binding.',
          'Use a PNG path inside the conversation’s bound workspace; do not use absolute paths or overwrite existing files.',
        ),
      'browser_tab_owner_changed' => const BrowserFailure(
        'browser_tab_owner_changed',
        'The tab changed conversations while the operation was pending.',
        'Use list_tabs to select a tab owned by this conversation.',
      ),
      final String value => BrowserFailure(
        value,
        'The browser could not complete this action.',
        'Inspect the current page and check the action arguments before retrying.',
      ),
      _ => const BrowserFailure(
        'browser_action_failed',
        'The browser action failed.',
        'Inspect the current page before retrying; reopen the tab if the renderer is unavailable.',
      ),
    };
  }

  Map<String, dynamic> toJson() => {
    'error_code': code,
    'error': message,
    'recoverable': recoverable,
    'outcome_unknown': outcomeUnknown,
    'next_action': nextAction,
  };

  @override
  String toString() => '$code: $message';
}
