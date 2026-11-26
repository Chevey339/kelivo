abstract final class AttachmentRetention {
  static const preferenceKey = 'attachment_retention_days';
  static const defaultDays = 7;
  static const maxDays = 3650;

  static int days(Object? value) =>
      value is int ? value.clamp(0, maxDays) : defaultDays;
}
