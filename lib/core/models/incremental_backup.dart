class ConvRange {
  final int count;
  final int messageCount;
  final String? oldestTitle;
  final String? newestTitle;
  const ConvRange({
    required this.count,
    required this.messageCount,
    this.oldestTitle,
    this.newestTitle,
  });
}

class IncrementalScope {
  final ConvRange newConversations;
  final ConvRange updatedConversations;
  final int newFileCount;
  final int totalFileSizeBytes;
  const IncrementalScope({
    required this.newConversations,
    required this.updatedConversations,
    required this.newFileCount,
    required this.totalFileSizeBytes,
  });
}

class IncrementalBackupConfig {
  final DateTime since;
  final bool includeSettings;
  final bool includeFiles;
  final bool updateBackupTime;
  final IncrementalScope? scope;
  const IncrementalBackupConfig({
    required this.since,
    this.includeSettings = true,
    this.includeFiles = true,
    this.updateBackupTime = true,
    this.scope,
  });
}
