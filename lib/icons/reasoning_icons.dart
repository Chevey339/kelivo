import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/models/model_spec.dart';

class ReasoningIcons {
  static const int offBudget = 0;
  static const int autoBudget = -1;
  static const int lightBudget = 1024;
  static const int mediumBudget = 16000;
  static const int heavyBudget = 32000;
  static const int xhighBudget = 64000;
  static const int maxBudget = 128000;

  static const String offAsset = 'assets/icons/idea-01-no-rays.svg';
  static const String autoAsset = 'assets/icons/idea-01-stroke-rounded.svg';
  static const String lightAsset = 'assets/icons/idea-01-no-side-rays.svg';
  static const String mediumAsset = 'assets/icons/idea-01-stroke-rounded.svg';
  static const String heavyAsset = 'assets/icons/idea-01-more-rays.svg';
  static const String xhighAsset = 'assets/icons/idea-01-moremore-rays.svg';
  static const String maxAsset = xhighAsset;
  static const String thinkingCardAsset = mediumAsset;

  static String assetForLevel(ReasoningLevel level) {
    return switch (level) {
      ReasoningLevel.off => offAsset,
      ReasoningLevel.auto => autoAsset,
      ReasoningLevel.minimal || ReasoningLevel.low => lightAsset,
      ReasoningLevel.medium => mediumAsset,
      ReasoningLevel.high => heavyAsset,
      ReasoningLevel.xhigh || ReasoningLevel.max => xhighAsset,
    };
  }

  static Widget levelIcon(
    ReasoningLevel level, {
    required double size,
    required Color color,
  }) {
    return SvgPicture.asset(
      assetForLevel(level),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  static String assetForBudget(int? budget) {
    if (budget == null || budget == autoBudget) return autoAsset;
    if (budget == offBudget) return offAsset;
    if (budget <= lightBudget) return lightAsset;
    if (budget <= mediumBudget) return mediumAsset;
    if (budget <= heavyBudget) return heavyAsset;
    if (budget <= xhighBudget) return xhighAsset;
    return maxAsset;
  }

  static Widget budgetIcon(
    int? budget, {
    required double size,
    required Color color,
  }) {
    return SvgPicture.asset(
      assetForBudget(budget),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  static Widget thinkingCardIcon({required double size, required Color color}) {
    return SvgPicture.asset(
      thinkingCardAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
