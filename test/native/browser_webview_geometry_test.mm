// Diagnostic native regression. Uses the current SDK's engine binary/headers;
// no Flutter app is launched and the probe never activates a window.
//
// xcrun clang++ -std=c++17 -fobjc-arc -I"$FLUTTER_ROOT/engine/src" \
//   -framework Cocoa -framework WebKit test/native/browser_webview_geometry_test.mm \
//   -o /tmp/browser-webview-geometry-test
// /tmp/browser-webview-geometry-test \
//   build/macos/Build/Products/Profile/FlutterMacOS.framework/FlutterMacOS
//
// Uses the same four immediate-parent constraints as the Swift host patch.
// It exercises actual AppKit alignment and Flutter clipping, including the
// WebKit content-host geometry that an outer-frame-only assertion misses.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <dlfcn.h>
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterMutatorView.h"

// The engine does not export this C++ constructor. Keep the exact installed
// header's value object; its actual Objective-C mutator consumes that object.
namespace flutter {
PlatformViewLayer::PlatformViewLayer(
    FlutterPlatformViewIdentifier identifier,
    const std::vector<FlutterPlatformViewMutation>& mutations,
    FlutterPoint offset,
    FlutterSize size)
    : identifier_(identifier), mutations_(mutations), offset_(offset), size_(size) {}
}

// Negative control for the previous frame-only fix: an unconstrained WK view
// can have a correct outer frame while its internal rendering host is 0 x 0.
@interface FrameOnlyHost : NSView
@end
@implementation FrameOnlyHost
- (void)layoutWebView {
  for (NSView* child in self.subviews) {
    if ([child isKindOfClass:WKWebView.class]) {
      if (!NSEqualRects(child.frame, self.bounds)) child.frame = self.bounds;
      return;
    }
  }
}
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
  [super resizeSubviewsWithOldSize:oldSize];
  [self layoutWebView];
}
- (void)layout {
  [super layout];
  [self layoutWebView];
}
- (void)didAddSubview:(NSView*)subview {
  [super didAddSubview:subview];
  [self layoutWebView];
}
@end

static void Require(bool condition, const char* message) {
  if (condition) return;
  fprintf(stderr, "FAIL: %s\n", message);
  std::exit(1);
}

enum class Layout { Upstream, FrameOnly, Constrained };

struct Result {
  double maxDrift;
  bool collapsedContent;
};

static Result Run(Layout layout, Class mutatorClass) {
  NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1100, 800)
                                               styleMask:NSWindowStyleMaskBorderless
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
  window.releasedWhenClosed = NO;
  NSView* root = window.contentView;
  NSView* parent = [[NSView alloc] initWithFrame:root.bounds];
  parent.translatesAutoresizingMaskIntoConstraints = NO;
  [root addSubview:parent];
  [NSLayoutConstraint activateConstraints:@[
    [parent.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
    [parent.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
    [parent.topAnchor constraintEqualToAnchor:root.topAnchor],
    [parent.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
  ]];
  parent.wantsLayer = YES;
  const double scale = window.backingScaleFactor;
  parent.layer.contentsScale = scale;
  const NSRect headlessFrame = NSMakeRect(0, 0, 520, 788);
  NSView* host = layout == Layout::FrameOnly
                    ? [[FrameOnlyHost alloc] initWithFrame:NSZeroRect]
                    : [[NSView alloc] initWithFrame:NSZeroRect];
  host.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  WKWebView* page = [[WKWebView alloc] initWithFrame:host.bounds];
  // Inspect the existing first content-host child through public NSView APIs.
  // Never identify or modify a private WebKit class or its layer properties.
  NSView* contentHost = page.subviews.firstObject;
  Require(contentHost != nil, "WK did not create a content-host subview");
  page.translatesAutoresizingMaskIntoConstraints = layout == Layout::Upstream;
  page.autoresizingMask = layout == Layout::Upstream
                             ? NSViewWidthSizable | NSViewHeightSizable
                             : NSViewNotSizable;
  [host addSubview:page];
  NSArray<NSLayoutConstraint*>* edgeConstraints = @[
    [page.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
    [page.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
    [page.topAnchor constraintEqualToAnchor:host.topAnchor],
    [page.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
  ];
  if (layout == Layout::Constrained)
    [NSLayoutConstraint activateConstraints:edgeConstraints];
  if (@available(macOS 26.0, *)) page.obscuredContentInsets = NSEdgeInsetsMake(84, 0, 0, 0);
  [page loadHTMLString:@"<html><body style='margin:0;background:white'>Geometry</body></html>"
              baseURL:nil];
  [parent addSubview:host];

  // Native glass/text controls activate AppKit layout in the complete app.
  // A small unrelated constrained sibling activates that same layout machinery.
  NSView* layoutTrigger = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  layoutTrigger.translatesAutoresizingMaskIntoConstraints = NO;
  [host addSubview:layoutTrigger];
  [NSLayoutConstraint activateConstraints:@[
    [layoutTrigger.widthAnchor constraintEqualToConstant:10],
    [layoutTrigger.heightAnchor constraintEqualToConstant:10],
    [layoutTrigger.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
    [layoutTrigger.topAnchor constraintEqualToAnchor:host.topAnchor],
  ]];

  host.frame = headlessFrame;
  [root updateConstraintsForSubtreeIfNeeded];
  [root layoutSubtreeIfNeeded];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  bool collapsedContent = NSIsEmptyRect(contentHost.bounds);
  if (layout == Layout::Constrained)
    Require(NSEqualRects(contentHost.frame, page.bounds), "headless content host collapsed");

  // The plugin transfers a preloaded headless host through a zero initial
  // platform-view frame before Flutter supplies its rendered dimensions.
  host.frame = NSZeroRect;
  [root updateConstraintsForSubtreeIfNeeded];
  [root layoutSubtreeIfNeeded];
  [host removeFromSuperview];
  FlutterMutatorView* mutator = [[mutatorClass alloc] initWithPlatformView:host];
  [parent addSubview:mutator];

  auto apply = [&](double width, bool clipped, bool fullPage) {
    const double x = fullPage ? 0 : 1100 - width;
    std::vector<FlutterPlatformViewMutation> mutations{
        {.type = kFlutterPlatformViewMutationTypeTransformation,
         .transformation = {.scaleX = scale, .scaleY = scale}},
        {.type = kFlutterPlatformViewMutationTypeClipRect,
         .clip_rect = {x + (clipped ? 64 : 0), 0, x + width, 800}},
        {.type = kFlutterPlatformViewMutationTypeTransformation,
         .transformation = {.scaleX = 1, .transX = x, .scaleY = 1}},
    };
    flutter::PlatformViewLayer layer(0, mutations, {0, 0}, {width * scale, 800 * scale});
    [mutator applyFlutterLayer:&layer];
    [root updateConstraintsForSubtreeIfNeeded];
    [root layoutSubtreeIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
  };

  auto requireViewport = [&] {
    Require(NSEqualRects(page.frame, host.bounds), "WK frame does not fill host bounds");
    Require(NSEqualRects(contentHost.frame, page.bounds), "WK content host does not fill WK bounds");
    Require(!NSIsEmptyRect(contentHost.bounds), "WK content would be clipped to zero area");
  };
  apply(707, false, false);
  collapsedContent |= NSIsEmptyRect(contentHost.bounds);
  if (layout == Layout::Constrained) requireViewport();
  double maxDrift = 0;
  for (int step = 0; step < 800; step++) {
    apply(520.3984375 + std::sin(step * .7) * 100, step >= 400, false);
    maxDrift = std::max(maxDrift, std::abs(page.frame.origin.x));
    collapsedContent |= NSIsEmptyRect(contentHost.bounds);
    if (layout == Layout::Constrained) requireViewport();
  }
  apply(1100, false, true);
  if (layout == Layout::Constrained) {
    requireViewport();
    const NSUInteger hostConstraintCount = host.constraints.count;
    // WebKit saves immediate-superview constraints before fullscreen reparenting
    // and reactivates those same constraints on return. Model that public
    // remove/add/activate sequence, without invoking private fullscreen methods.
    NSView* fullscreenHost = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 900, 600)];
    [page removeFromSuperview];
    for (NSLayoutConstraint* constraint in edgeConstraints)
      Require(!constraint.active, "detached WK retained an active browser-host constraint");
    [fullscreenHost addSubview:page];
    const NSRect fullscreenFrame = NSMakeRect(0, 0, 900, 600);
    page.frame = fullscreenFrame;
    apply(420.3984375, false, false);
    Require(NSEqualRects(page.frame, fullscreenFrame), "browser host changed detached fullscreen page");
    [page removeFromSuperview];
    [host addSubview:page];
    [NSLayoutConstraint activateConstraints:edgeConstraints];
    [root updateConstraintsForSubtreeIfNeeded];
    [root layoutSubtreeIfNeeded];
    requireViewport();
    Require(host.constraints.count == hostConstraintCount, "reattachment duplicated host constraints");
  }
  [window close];
  return {maxDrift, collapsedContent};
}

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    Require(argc == 2, "pass the matching FlutterMacOS engine binary path");
    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyProhibited];
    Require(dlopen(argv[1], RTLD_NOW) != nullptr, "could not load FlutterMacOS");
    Class mutatorClass = NSClassFromString(@"FlutterMutatorView");
    Require(mutatorClass != Nil, "matching engine does not expose its testable mutator");
    const Result baseline = Run(Layout::Upstream, mutatorClass);
    const Result frameOnly = Run(Layout::FrameOnly, mutatorClass);
    const Result constrained = Run(Layout::Constrained, mutatorClass);
    Require(baseline.maxDrift > .25, "control did not reproduce upstream fractional-layout drift");
    Require(frameOnly.collapsedContent, "control did not reproduce the frame-only black viewport");
    Require(constrained.maxDrift == 0 && !constrained.collapsedContent,
            "constrained layout drifted or collapsed the content host");
    printf("Native geometry passed: upstream drift %.3f pt; frame-only content collapse reproduced; "
           "constrained drift %.3f pt with nonzero matching WK content bounds\n",
           baseline.maxDrift, constrained.maxDrift);
  }
  return 0;
}
