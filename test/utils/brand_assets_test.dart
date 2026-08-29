import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandAssets', () {
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
      final parallel = BrandAssets.assetForName('Parallel');
      final you = BrandAssets.assetForName('You.com');
      final azure = BrandAssets.assetForName('Azure');

      expect(stepFun, 'assets/icons/stepfun.svg');
      expect(firecrawl, 'assets/icons/firecrawl-color.svg');
      expect(tinyFish, 'assets/icons/tinyfish-color.svg');
      expect(anySearch, 'assets/icons/anysearch.svg');
      expect(parallel, 'assets/icons/parallel.svg');
      expect(you, 'assets/icons/you.svg');
      expect(azure, 'assets/icons/azure-speech.svg');
      expect(BrandAssets.assetForName('Azure AI Search'), isNull);
      expect(BrandAssets.selectableAssetOrNull(stepFun!), stepFun);
      expect(BrandAssets.selectableAssetOrNull(firecrawl!), firecrawl);
      expect(BrandAssets.selectableAssetOrNull(tinyFish!), tinyFish);
      expect(BrandAssets.selectableAssetOrNull(anySearch!), anySearch);
      expect(BrandAssets.selectableAssetOrNull(parallel!), parallel);
      expect(BrandAssets.selectableAssetOrNull(you!), you);
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
