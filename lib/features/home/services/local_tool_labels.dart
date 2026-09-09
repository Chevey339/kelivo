import 'package:flutter/widgets.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import 'local_tools_service.dart';

/// Ids of the local tools offered on this platform, in the order the assistant
/// "Local tools" tab lists them.
List<String> availableLocalToolIds() => [
  for (final id in LocalToolNames.all)
    if (LocalToolsService.isAvailableOnThisPlatform(id)) id,
];

IconData localToolIcon(String id) {
  switch (id) {
    case LocalToolNames.timeInfo:
      return Lucide.clock;
    case LocalToolNames.clipboard:
      return Lucide.Clipboard;
    case LocalToolNames.textToSpeech:
      return Lucide.Volume2;
    case LocalToolNames.askUser:
      return Lucide.MessageCircleQuestionMark;
    case LocalToolNames.calculate:
      return Lucide.Calculator;
    case LocalToolNames.screenTime:
      return Lucide.Smartphone;
    case LocalToolNames.calendarQuery:
      return Lucide.Calendar;
    case LocalToolNames.calendarCreate:
      return Lucide.CalendarPlus;
    case LocalToolNames.currentLocation:
      return Lucide.MapPin;
    case LocalToolNames.weather:
      return Lucide.CloudSun;
    case LocalToolNames.healthSummary:
      return Lucide.HeartPulse;
    case LocalToolNames.remindersQuery:
      return Lucide.ListTodo;
    case LocalToolNames.remindersCreate:
      return Lucide.ListPlus;
    case LocalToolNames.remindersComplete:
      return Lucide.CheckCircle;
    default:
      return Lucide.Wrench;
  }
}

String localToolTitle(AppLocalizations l10n, String id) {
  switch (id) {
    case LocalToolNames.timeInfo:
      return l10n.assistantEditLocalToolTimeInfoTitle;
    case LocalToolNames.clipboard:
      return l10n.assistantEditLocalToolClipboardTitle;
    case LocalToolNames.textToSpeech:
      return l10n.assistantEditLocalToolTextToSpeechTitle;
    case LocalToolNames.askUser:
      return l10n.assistantEditLocalToolAskUserTitle;
    case LocalToolNames.calculate:
      return l10n.assistantEditLocalToolCalculateTitle;
    case LocalToolNames.screenTime:
      return l10n.assistantEditLocalToolScreenTimeTitle;
    case LocalToolNames.calendarQuery:
      return l10n.assistantEditLocalToolCalendarQueryTitle;
    case LocalToolNames.calendarCreate:
      return l10n.assistantEditLocalToolCalendarCreateTitle;
    case LocalToolNames.currentLocation:
      return l10n.assistantEditLocalToolLocationTitle;
    case LocalToolNames.weather:
      return l10n.assistantEditLocalToolWeatherTitle;
    case LocalToolNames.healthSummary:
      return l10n.assistantEditLocalToolHealthTitle;
    case LocalToolNames.remindersQuery:
      return l10n.assistantEditLocalToolRemindersQueryTitle;
    case LocalToolNames.remindersCreate:
      return l10n.assistantEditLocalToolRemindersCreateTitle;
    case LocalToolNames.remindersComplete:
      return l10n.assistantEditLocalToolRemindersCompleteTitle;
    default:
      return id;
  }
}
