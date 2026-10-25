// SPDX-License-Identifier: GPL-3.0-or-later
// Runtime mechanism adapted from Telegram-iOS. See UPSTREAM.md and COPYING.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// An iOS 17–25 live backdrop mesh. Creation fails closed if the runtime does
/// not provide the expected Core Animation classes, selectors or KVC keys.
@interface KLVBrowserLegacyGlassLayer : CALayer
+ (nullable instancetype)makeLayer NS_SWIFT_NAME(make());
- (BOOL)configureClear:(BOOL)clear dark:(BOOL)dark NS_SWIFT_NAME(configure(clear:dark:));
- (BOOL)updateBounds:(CGRect)bounds radius:(CGFloat)radius NS_SWIFT_NAME(update(bounds:radius:));
@end

NS_ASSUME_NONNULL_END
