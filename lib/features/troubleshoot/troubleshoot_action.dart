import 'package:flutter/material.dart';
import '../../core/services/troubleshoot/troubleshoot_data.dart';
import '../provider/pages/provider_detail_page.dart';
import '../provider/pages/provider_balance_page.dart';
import '../model/pages/default_model_page.dart';
import '../search/pages/search_services_page.dart';
import '../assistant/pages/assistant_settings_page.dart';
import '../backup/pages/backup_page.dart';
import '../settings/pages/about_page.dart';

void dispatchAction(BuildContext context, TroubleshootAction action) {
  switch (action.type) {
    case ActionType.openProviderDetail:
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProviderDetailPage(
            keyName: action.providerId ?? '',
            displayName: action.providerDisplayName ?? action.providerId ?? '',
          ),
        ),
      );
      break;
    case ActionType.openProviderBalance:
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProviderBalancePage(
            providerKey: action.providerId ?? '',
            providerDisplayName: action.providerDisplayName ?? '',
          ),
        ),
      );
      break;
    case ActionType.openDefaultModel:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DefaultModelPage()));
      break;
    case ActionType.openSearchServices:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SearchServicesPage()));
      break;
    case ActionType.openAssistantSettings:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AssistantSettingsPage()));
      break;
    case ActionType.openBackupSettings:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const BackupPage()));
      break;
    case ActionType.openAbout:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
      break;
    case ActionType.openCommunityLinks:
      break;
  }
}
