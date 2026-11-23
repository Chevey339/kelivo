import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandAssets', () {
    test('recognizes media model families independently of the gateway', () {
      for (final entry in {
        'qwen-image-2.1-pro': 'qwen-color.svg',
        'qwen-image-2.1-turbo': 'qwen-color.svg',
        'openai/dall-e-3': 'openai.svg',
        'dashscope/wan2.6-image': 'alibabacloud-color.svg',
        'fal-ai/nano-banana/edit': 'gemini-color.svg',
        'Nano Banana Pro': 'gemini-color.svg',
        'DALL·E 2': 'openai.svg',
        'imagen-4.0-generate-001': 'google-color.svg',
        'veo-3.1-fast': 'google-color.svg',
        'wan2.6-image': 'alibabacloud-color.svg',
        'wanx2.1-i2v-plus': 'alibabacloud-color.svg',
      }.entries) {
        expect(
          BrandAssets.assetForName(entry.key),
          'assets/icons/${entry.value}',
        );
      }
      expect(BrandAssets.assetForName('swan-song'), isNull);
      expect(BrandAssets.assetForName('imagenation'), isNull);
      expect(
        BrandAssets.assetForModel('endpoint-123', displayName: 'Example Image'),
        isNull,
      );
      expect(BrandAssets.assetForModel('Bingo Portrait'), isNull);
      expect(BrandAssets.assetForModel('openrouter/endpoint-123'), isNull);
      expect(BrandAssets.assetForModel('dashscope/endpoint-123'), isNull);
      expect(
        BrandAssets.assetForModel('openai/text-embedding-3-large'),
        'assets/icons/openai.svg',
      );
      expect(
        BrandAssets.assetForModel(
          'minimax/h3-max/text-to-video',
          displayName: 'Studio A',
        ),
        'assets/icons/minimax-color.svg',
      );
      expect(
        BrandAssets.assetForModel(
          'openai/endpoint-123',
          displayName: 'Qwen Image Turbo',
        ),
        'assets/icons/qwen-color.svg',
      );
    });
    test('Vercel Gateway icon is selectable and adapts to dark mode', () {
      const asset = 'assets/icons/vercel.svg';
      expect(BrandAssets.assetForName('Vercel AI Gateway'), asset);
      expect(BrandAssets.selectableAssetOrNull(asset), asset);
      expect(BrandAssets.assetNeedsDarkInvert(asset), isTrue);
    });

    test('mapped Metaso icon is selectable as a built-in provider avatar', () {
      final asset = BrandAssets.assetForName('metaso');

      expect(asset, 'assets/icons/metaso-color.svg');
      expect(BrandAssets.selectableAssetOrNull(asset!), asset);
    });

    test('maps the new providers to their official icon variants', () {
      final stepFun = BrandAssets.assetForName('StepFun');
      final firecrawl = BrandAssets.assetForName('Firecrawl');
      final tinyFish = BrandAssets.assetForName('TinyFish');
      final anySearch = BrandAssets.assetForName('AnySearch');
      final kagi = BrandAssets.assetForName('Kagi');
      final parallel = BrandAssets.assetForName('Parallel');
      final you = BrandAssets.assetForName('You.com');
      final azure = BrandAssets.assetForName('Azure');

      expect(stepFun, 'assets/icons/stepfun.svg');
      expect(firecrawl, 'assets/icons/firecrawl-color.svg');
      expect(tinyFish, 'assets/icons/tinyfish-color.svg');
      expect(anySearch, 'assets/icons/anysearch.svg');
      expect(kagi, 'assets/icons/kagi-color.svg');
      expect(parallel, 'assets/icons/parallel.svg');
      expect(you, 'assets/icons/you.svg');
      expect(azure, 'assets/icons/azure-speech.svg');
      expect(BrandAssets.assetForName('Azure AI Search'), isNull);
      expect(BrandAssets.selectableAssetOrNull(stepFun!), stepFun);
      expect(BrandAssets.selectableAssetOrNull(firecrawl!), firecrawl);
      expect(BrandAssets.selectableAssetOrNull(tinyFish!), tinyFish);
      expect(BrandAssets.selectableAssetOrNull(anySearch!), anySearch);
      expect(BrandAssets.selectableAssetOrNull(kagi!), kagi);
      expect(BrandAssets.selectableAssetOrNull(parallel!), parallel);
      expect(BrandAssets.selectableAssetOrNull(you!), you);
    });

    test('maps You.com Search without matching nearby names', () {
      expect(
        BrandAssets.assetForName('You.com Search'),
        'assets/icons/you.svg',
      );
      expect(BrandAssets.assetForName('You.com'), 'assets/icons/you.svg');
      expect(BrandAssets.assetForName('you'), 'assets/icons/you.svg');
      expect(BrandAssets.assetForName('you.com'), 'assets/icons/you.svg');
      expect(BrandAssets.assetForName('YouTube'), isNull);
      expect(BrandAssets.assetForName('your search'), isNull);
    });

    test('distinguishes monochrome SVGs from colored brand assets', () {
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/openai.svg'),
        isTrue,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/linkup.svg'),
        isTrue,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/stepfun.svg'),
        isTrue,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/firecrawl.svg'),
        isTrue,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/fish-audio.svg'),
        isTrue,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/anysearch.svg'),
        isTrue,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/parallel.svg'),
        isTrue,
      );
      expect(BrandAssets.assetNeedsDarkInvert('assets/icons/you.svg'), isFalse);
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/serper.svg'),
        isFalse,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/gemini-color.svg'),
        isFalse,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/firecrawl-color.svg'),
        isFalse,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/tinyfish-color.svg'),
        isFalse,
      );
      expect(
        BrandAssets.assetNeedsDarkInvert('assets/icons/kelivo.png'),
        isFalse,
      );
    });
  });
}
