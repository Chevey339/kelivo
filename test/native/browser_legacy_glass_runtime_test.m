// SPDX-License-Identifier: GPL-3.0-or-later
#import "../../ios/Runner/BrowserGlass/BrowserLegacyGlassRuntime.h"
#include <assert.h>
#include <stdio.h>
#include <math.h>

int main(void) {
  @autoreleasepool {
    KLVBrowserLegacyGlassLayer *layer = [KLVBrowserLegacyGlassLayer makeLayer];
    assert(layer != nil);
    assert(layer.sublayers.count == 1);
    CALayer *backdrop = layer.sublayers.firstObject;
    assert([NSStringFromClass(backdrop.class) isEqualToString:@"CABackdropLayer"]);
    for (int dark = 0; dark < 2; dark++) {
      for (int clear = 0; clear < 2; clear++) {
        assert([layer configureClear:clear dark:dark]);
        assert(backdrop.filters.count == 2);
        NSArray *filters = backdrop.filters;
        assert([layer configureClear:clear dark:dark]);
        assert(backdrop.filters == filters);
        float matrix[20];
        NSValue *value = [filters.firstObject valueForKey:@"inputColorMatrix"];
        [value getValue:matrix size:sizeof(matrix)];
        float black = matrix[4];
        float white = matrix[0] + matrix[1] + matrix[2] + matrix[4];
        assert(black >= 0 && white <= 1 && white > black);
        if (dark) assert(white < (clear ? .60 : .45));
        else assert(black > (clear ? .45 : .60));
      }
    }
    assert([layer updateBounds:CGRectMake(0, 0, 300, 44) radius:1000]);
    id mesh = [backdrop valueForKey:@"meshTransform"];
    assert(mesh != nil);
    assert([layer updateBounds:CGRectMake(0, 0, 300, 44) radius:22]);
    assert([backdrop valueForKey:@"meshTransform"] == mesh);
    assert([layer updateBounds:CGRectMake(0, 0, 250, 400) radius:25]);
    assert([backdrop valueForKey:@"meshTransform"] != mesh);
    assert(![layer updateBounds:CGRectMake(NAN, 0, 44, 44) radius:22]);
    assert(layer.sublayers.count == 0);
    assert(![layer configureClear:NO dark:NO]);
    puts("legacy glass runtime: live class/qualified ABI, mesh creation/cache, theme matrix and failure cleanup passed");
  }
  return 0;
}
