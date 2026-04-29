#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KelivoOpenMinisRuntimeBridge : NSObject

- (NSDictionary<NSString *, id> *)runtimeStatus;
- (FlutterError *_Nullable)installRuntimeWithArguments:(NSDictionary<NSString *, id> *)arguments;
- (FlutterError *_Nullable)startSessionWithArguments:(NSDictionary<NSString *, id> *)arguments;
- (FlutterError *_Nullable)writeSessionWithArguments:(NSDictionary<NSString *, id> *)arguments;
- (FlutterError *_Nullable)resizeSessionWithArguments:(NSDictionary<NSString *, id> *)arguments;
- (FlutterError *_Nullable)stopSessionWithArguments:(NSDictionary<NSString *, id> *)arguments;
- (id)runCommandWithArguments:(NSDictionary<NSString *, id> *)arguments;
- (NSDictionary<NSString *, id> *)diagnosticLog;
- (void)appendDiagnosticWithArguments:(NSDictionary<NSString *, id> *)arguments;
- (NSArray<NSDictionary<NSString *, id> *> *)drainEvents;

@end

NS_ASSUME_NONNULL_END
