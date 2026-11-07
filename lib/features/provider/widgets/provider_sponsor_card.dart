import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_font_weights.dart';

class ProviderSponsorCard extends StatelessWidget {
  const ProviderSponsorCard({super.key, required this.providerKey});

  final String providerKey;

  @override
  Widget build(BuildContext context) {
    final info = switch (providerKey.toLowerCase()) {
      'sta1n api' => (
        description: '专注角色扮演（RP）与角色聊天的 API 服务。感谢 STA1N API 对 Kelivo 的赞助与支持！',
        website: 'https://sta1n.ai/',
        purchaseUrl: null,
      ),
      '10dian-api' => (
        description:
            '10dian-API 为广大开发者和玩家提供安全·快速·稳定的 API 服务，资费透明·价格低廉·体验至上，承诺 100% 不掺水。用一把钥匙，召唤全世界的 AI～',
        website: 'https://api.10dianai.com',
        purchaseUrl: null,
      ),
      '砂糖酒馆' => (
        description:
            '主营角色聊天，按次收费，价格透明。提供 Gemini、Claude、DeepSeek、GLM 等主流文本模型，以及 NAI 生图、TTS 和视频模型。注重隐私，无数据倒卖，无模型掺水，充值额度 1:1。',
        website: 'https://ai.ota1245.top/',
        purchaseUrl: 'https://www.16688.com.cn/shop/S929990',
      ),
      _ => null,
    };
    if (info == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.description,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 6),
          _link(context, label: '官网：', url: info.website),
          if (info.purchaseUrl case final String purchaseUrl) ...[
            const SizedBox(height: 6),
            _link(context, label: '购买：', url: purchaseUrl),
          ],
        ],
      ),
    );
  }

  Widget _link(
    BuildContext context, {
    required String label,
    required String url,
  }) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        link: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openLink(url),
          child: Text.rich(
            TextSpan(
              text: label,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
              children: [
                TextSpan(
                  text: url,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) await launchUrl(uri);
    } catch (_) {
      await launchUrl(uri);
    }
  }
}
