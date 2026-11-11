import 'dart:io';

/// A valid Responses result that stopped before completion, not a transport
/// failure. Its final usage and partial output must be consumed before throwing.
class ResponseIncompleteException extends HttpException {
  ResponseIncompleteException({required this.reason, this.inputTokens})
    : super('Provider error: response incomplete ($reason)');

  final String reason;
  // From this response's usage, never the sum of a turn's tool requests.
  final int? inputTokens;
}
