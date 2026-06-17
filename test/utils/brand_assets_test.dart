import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandAssets', () {
    test('mapped Metaso icon is selectable as a built-in provider avatar', () {
      final asset = BrandAssets.assetForName('metaso');

      expect(asset, 'assets/icons/metaso-color.svg');
      expect(BrandAssets.selectableAssetOrNull(asset!), asset);
    });
  });
}
