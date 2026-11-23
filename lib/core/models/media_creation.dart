enum MediaMode { image, video }

enum GenerationTitleSource { auto, prompt, manual }

enum GenerationStatus {
  queued,
  running,
  downloading,
  succeeded,
  partial,
  failed,
  cancelled,
  interrupted;

  bool get isActive => this == queued || this == running || this == downloading;
}

enum GenerationSource { workbench, edit, chat }

enum GenerationItemStatus { pending, ready, failed }
