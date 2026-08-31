import 'package:Kelivo/core/services/api/retry_policy.dart';
import 'package:Kelivo/features/home/services/translation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('replaced translation run does not own side effects', () {
    final oldRun = Object();
    final newRun = Object();
    expect(translationRunIsCurrent(oldRun, newRun), isFalse);
    expect(
      shouldApplyTranslationFailure(
        runToken: oldRun,
        currentToken: newRun,
        error: Exception('HTTP 429: busy'),
      ),
      isFalse,
    );
  });

  test('cancelled translation does not clear the newer result', () {
    final run = Object();
    expect(
      shouldApplyTranslationFailure(
        runToken: run,
        currentToken: run,
        error: http.ClientException('cancelled'),
      ),
      isFalse,
    );
    expect(
      shouldApplyTranslationFailure(
        runToken: run,
        currentToken: run,
        error: Exception('HTTP 500: oops'),
      ),
      isTrue,
    );
    expect(isUserCancelError(http.ClientException('cancelled')), isTrue);
  });

  test('clear supersedes the old run so it cannot write translation back', () {
    final runs = <String, Object>{};
    final oldRun = Object();
    runs['m1'] = oldRun;
    final clearToken = supersedeTranslationRun(runs, 'm1');
    expect(translationRequestId('m1'), 'translate-msg-m1');
    expect(identical(runs['m1'], clearToken), isTrue);
    expect(translationRunIsCurrent(oldRun, runs['m1']), isFalse);
    expect(
      shouldApplyTranslationFailure(
        runToken: oldRun,
        currentToken: runs['m1'],
        error: Exception('HTTP 429: busy'),
      ),
      isFalse,
    );
  });
}
