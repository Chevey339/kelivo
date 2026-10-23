// SPDX-License-Identifier: GPL-3.0-or-later
// Runtime mechanism adapted from Telegram-iOS. See UPSTREAM.md and COPYING.
#import "BrowserLegacyGlassRuntime.h"
#import "BrowserGlassMesh.h"
#include <string.h>

static const char *KLVUnqualifiedObjCType(const char *type) {
  while (*type && strchr("rnNoORV", *type)) type++;
  return type;
}

@protocol KLVGlassRuntimeFactory <NSObject>
+ (id)filterWithName:(NSString *)name;
+ (id)meshTransformWithVertexCount:(NSUInteger)vertexCount vertices:(KLVGlassVertex *)vertices
                       faceCount:(NSUInteger)faceCount faces:(KLVGlassFace *)faces
              depthNormalization:(NSString *)depthNormalization;
@end

@interface KLVBrowserLegacyGlassLayer () {
  CALayer *_backdrop;
  Class _meshClass;
  Class _filterClass;
  CGRect _lastBounds;
  CGFloat _lastRadius;
  BOOL _hasGeometry;
  BOOL _hasAppearance;
  BOOL _clear;
  BOOL _dark;
  BOOL _valid;
}
@end

@implementation KLVBrowserLegacyGlassLayer

+ (instancetype)makeLayer {
  // These runtime names are intentionally explicit; they are not UIKit API.
  @try {
    Class backdropClass = NSClassFromString(@"CABackdropLayer");
    Class meshClass = NSClassFromString(@"CAMutableMeshTransform");
    Class filterClass = NSClassFromString(@"CAFilter");
    SEL meshSelector = @selector(meshTransformWithVertexCount:vertices:faceCount:faces:depthNormalization:);
    if (![backdropClass isSubclassOfClass:[CALayer class]] ||
        ![meshClass respondsToSelector:meshSelector] ||
        ![filterClass respondsToSelector:@selector(filterWithName:)]) return nil;
    NSMethodSignature *signature = [meshClass methodSignatureForSelector:meshSelector];
    if (!signature || signature.numberOfArguments != 7 ||
        signature.methodReturnLength != sizeof(id) ||
        KLVUnqualifiedObjCType(signature.methodReturnType)[0] != '@' ||
        strcmp(KLVUnqualifiedObjCType([signature getArgumentTypeAtIndex:2]), @encode(NSUInteger)) != 0 ||
        KLVUnqualifiedObjCType([signature getArgumentTypeAtIndex:3])[0] != '^' ||
        strcmp(KLVUnqualifiedObjCType([signature getArgumentTypeAtIndex:4]), @encode(NSUInteger)) != 0 ||
        KLVUnqualifiedObjCType([signature getArgumentTypeAtIndex:5])[0] != '^' ||
        KLVUnqualifiedObjCType([signature getArgumentTypeAtIndex:6])[0] != '@') return nil;
    KLVBrowserLegacyGlassLayer *layer = [self layer];
    layer->_meshClass = meshClass;
    layer->_filterClass = filterClass;
    layer->_backdrop = [[backdropClass alloc] init];
    if (![layer->_backdrop respondsToSelector:NSSelectorFromString(@"setScale:")]) return nil;
    [layer->_backdrop setValue:@1.0 forKey:@"scale"];
    layer->_backdrop.rasterizationScale = 1;
    layer.masksToBounds = YES;
    layer.cornerCurve = kCACornerCurveContinuous;
    layer->_valid = YES;
    [layer addSublayer:layer->_backdrop];
    // Probe KVC and the mesh constructor now, including its result type. A
    // failed runtime never leaves an empty replacement for the ordinary blur.
    if (![layer configureClear:NO dark:NO] ||
        ![layer updateBounds:CGRectMake(0, 0, 44, 44) radius:22]) return nil;
    layer.frame = CGRectZero;
    layer->_backdrop.frame = CGRectZero;
    layer->_hasGeometry = NO;
    return layer;
  } @catch (__unused NSException *exception) {
    return nil;
  }
}

- (BOOL)invalidateRuntime {
  _valid = NO;
  [_backdrop removeFromSuperlayer];
  _backdrop = nil;
  return NO;
}

- (BOOL)configureClear:(BOOL)clear dark:(BOOL)dark {
  if (!_valid) return NO;
  if (_hasAppearance && clear == _clear && dark == _dark) return YES;
  @try {
    id blur = [(id<KLVGlassRuntimeFactory>)_filterClass filterWithName:@"gaussianBlur"];
    if (!blur) return [self invalidateRuntime];
    [blur setValue:@(clear ? 1.5 : 2.0) forKey:@"inputRadius"];
    NSArray *filters;
    {
      id color = [(id<KLVGlassRuntimeFactory>)_filterClass filterWithName:@"colorMatrix"];
      if (!color) return [self invalidateRuntime];
      // Blend the sampled page towards the foreground's theme in this same
      // pass. Flutter glyphs do not receive UIKit vibrancy: without a body
      // tint white glyphs disappear on white pages (and black on dark pages).
      // Clear material retains more of the refracted page than regular glass.
      const float saturation = 1.12;
      const float tint = clear ? 0.47 : 0.62;
      const float retention = 1 - tint;
      const float red = (1 - saturation) * 0.2126 * retention;
      const float green = (1 - saturation) * 0.7152 * retention;
      const float blue = (1 - saturation) * 0.0722 * retention;
      const float diagonal = saturation * retention;
      const float lift = (dark ? 0.07 : 0.98) * tint;
      float matrix[20] = {
        red + diagonal, green, blue, 0, lift,
        red, green + diagonal, blue, 0, lift,
        red, green, blue + diagonal, 0, lift,
        0, 0, 0, 1, 0
      };
      [color setValue:[NSValue valueWithBytes:matrix objCType:"{CAColorMatrix=ffffffffffffffffffff}"]
              forKey:@"inputColorMatrix"];
      [color setValue:@YES forKey:@"inputBackdropAware"];
      filters = @[color, blur];
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    @try { _backdrop.filters = filters; }
    @finally { [CATransaction commit]; }
    _clear = clear; _dark = dark; _hasAppearance = YES;
    return YES;
  } @catch (__unused NSException *exception) {
    return [self invalidateRuntime];
  }
}

- (BOOL)updateBounds:(CGRect)bounds radius:(CGFloat)radius {
  if (!_valid) return NO;
  if (!isfinite(bounds.origin.x) || !isfinite(bounds.origin.y) ||
      !isfinite(bounds.size.width) || !isfinite(bounds.size.height) ||
      !isfinite(radius)) return [self invalidateRuntime];
  if (CGRectIsEmpty(bounds)) return YES; // Flutter's initial host has no size.
  radius = KLVGlassClamp(radius, 0, fmin(bounds.size.width, bounds.size.height) * 0.5);
  if (_hasGeometry && CGRectEqualToRect(bounds, _lastBounds) && radius == _lastRadius) return YES;
  KLVGlassVertex vertices[KLVGlassMaxVertices];
  KLVGlassFace faces[KLVGlassMaxFaces];
  size_t vertexCount = 0, faceCount = 0;
  if (!KLVBuildGlassMesh(bounds.size, radius, vertices, &vertexCount, faces, &faceCount)) return [self invalidateRuntime];
  @try {
    id mesh = [(id<KLVGlassRuntimeFactory>)_meshClass
      meshTransformWithVertexCount:vertexCount vertices:vertices
      faceCount:faceCount faces:faces depthNormalization:@"none"];
    Class meshBase = NSClassFromString(@"CAMeshTransform");
    if (!mesh || !meshBase || ![mesh isKindOfClass:meshBase]) return [self invalidateRuntime];
    if (![mesh respondsToSelector:NSSelectorFromString(@"setSubdivisionSteps:")]) return [self invalidateRuntime];
    [mesh setValue:@0 forKey:@"subdivisionSteps"];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    @try {
      self.frame = bounds;
      self.cornerRadius = KLVGlassClamp(radius, 0, fmin(bounds.size.width, bounds.size.height) * 0.5);
      _backdrop.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
      [_backdrop setValue:mesh forKey:@"meshTransform"];
    } @finally { [CATransaction commit]; }
    _lastBounds = bounds; _lastRadius = radius; _hasGeometry = YES;
    return YES;
  } @catch (__unused NSException *exception) {
    return [self invalidateRuntime];
  }
}
@end
