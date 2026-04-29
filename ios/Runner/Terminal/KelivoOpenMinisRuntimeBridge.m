#import "KelivoOpenMinisRuntimeBridge.h"

#import <UIKit/UIKit.h>
#import <pthread.h>
#import <stdlib.h>
#import <string.h>

#if KELIVO_OPENMINIS_ISH
#import <CommonCrypto/CommonDigest.h>
#import <zlib.h>
#ifndef ISH_INTERNAL
#define ISH_INTERNAL 1
#endif
#ifndef GUEST_ARM64
#define GUEST_ARM64 1
#endif
#ifndef static_assert
#define static_assert _Static_assert
#endif
#include "../../../dependencies/ish-arm64/debug.h"
#include "../../../dependencies/ish-arm64/fs/dev.h"
#include "../../../dependencies/ish-arm64/fs/devices.h"
#include "../../../dependencies/ish-arm64/fs/fake.h"
#include "../../../dependencies/ish-arm64/fs/path.h"
#include "../../../dependencies/ish-arm64/fs/tty.h"
#include "../../../dependencies/ish-arm64/kernel/calls.h"
#include "../../../dependencies/ish-arm64/kernel/init.h"
#include "../../../dependencies/ish-arm64/kernel/task.h"
#endif

static NSString *const KelivoTerminalRuntimeId = @"ios-alpine-arm64";
static NSString *const KelivoTerminalIntegrationReference = @"OpenMinis iSH ARM64";
static NSString *const KelivoTerminalPackageSource = @"https://cdn.psycheas.top/ios-alpine-arm64/stable.json";

static NSString *KelivoTerminalSupportPath(void) {
  NSURL *applicationSupport = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                                   inDomains:NSUserDomainMask].firstObject;
  return [[applicationSupport URLByAppendingPathComponent:@"terminal" isDirectory:YES] path];
}

static NSString *KelivoTerminalOpenMinisRootPath(void) {
  return [KelivoTerminalSupportPath() stringByAppendingPathComponent:@"runtimes/ios-alpine-arm64/current"];
}

static NSString *KelivoTerminalRuntimeBasePath(void) {
  return [KelivoTerminalSupportPath() stringByAppendingPathComponent:@"runtimes/ios-alpine-arm64"];
}

static NSString *KelivoTerminalLogPath(void) {
  return [KelivoTerminalSupportPath() stringByAppendingPathComponent:@"logs/terminal.log"];
}

static NSString *KelivoTerminalLastErrorPath(void) {
  return [KelivoTerminalSupportPath() stringByAppendingPathComponent:@"logs/last_error.txt"];
}

static void KelivoTerminalAppendDiagnostic(NSString *message) {
  NSString *logPath = KelivoTerminalLogPath();
  NSString *parent = [logPath stringByDeletingLastPathComponent];
  [NSFileManager.defaultManager createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:nil];
  if (![NSFileManager.defaultManager fileExistsAtPath:logPath]) {
    [NSFileManager.defaultManager createFileAtPath:logPath contents:nil attributes:nil];
  }

  NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
  NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:NSDate.date], message];
  NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding] ?: NSData.data;
  NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
  if (handle == nil) {
    return;
  }
  @try {
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle synchronizeFile];
  } @catch (NSException *exception) {
  }
  [handle closeFile];
}

static void KelivoTerminalWriteLastError(NSString *code) {
  NSString *path = KelivoTerminalLastErrorPath();
  [NSFileManager.defaultManager createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:nil];
  [[code dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
}

static NSString *_Nullable KelivoTerminalLastError(void) {
  NSData *data = [NSData dataWithContentsOfFile:KelivoTerminalLastErrorPath()];
  if (data == nil) {
    return nil;
  }
  NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSDictionary *_Nullable KelivoTerminalRuntimeMetadata(void) {
  NSString *metadataPath = [KelivoTerminalRuntimeBasePath() stringByAppendingPathComponent:@"metadata.json"];
  NSData *data = [NSData dataWithContentsOfFile:metadataPath];
  if (data == nil) {
    return nil;
  }
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![json isKindOfClass:NSDictionary.class]) {
    return nil;
  }
  return json;
}

static unsigned long long KelivoDirectorySize(NSString *path) {
  NSDirectoryEnumerator<NSURL *> *enumerator =
      [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:path]
                         includingPropertiesForKeys:@[NSURLFileSizeKey]
                                            options:NSDirectoryEnumerationSkipsHiddenFiles
                                       errorHandler:nil];
  unsigned long long total = 0;
  for (NSURL *url in enumerator) {
    NSNumber *fileSize = nil;
    [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
    total += fileSize.unsignedLongLongValue;
  }
  return total;
}

static FlutterError *KelivoTerminalError(NSString *code, NSString *message, NSDictionary *_Nullable details) {
  return [FlutterError errorWithCode:code message:message details:details];
}

#if KELIVO_OPENMINIS_ISH
static NSString *_Nullable KelivoSHA256ForFile(NSString *path) {
  NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
  [stream open];
  if (stream.streamStatus == NSStreamStatusError) {
    [stream close];
    return nil;
  }

  CC_SHA256_CTX context;
  CC_SHA256_Init(&context);
  uint8_t buffer[64 * 1024];
  NSInteger bytesRead = 0;
  while ((bytesRead = [stream read:buffer maxLength:sizeof(buffer)]) > 0) {
    CC_SHA256_Update(&context, buffer, (CC_LONG)bytesRead);
  }
  [stream close];
  if (bytesRead < 0) {
    return nil;
  }

  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256_Final(digest, &context);
  NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [hex appendFormat:@"%02x", digest[i]];
  }
  return hex;
}

static BOOL KelivoGzReadFully(gzFile file, void *buffer, unsigned int length) {
  unsigned int offset = 0;
  while (offset < length) {
    int bytesRead = gzread(file, (char *)buffer + offset, length - offset);
    if (bytesRead <= 0) {
      return NO;
    }
    offset += (unsigned int)bytesRead;
  }
  return YES;
}

static BOOL KelivoAppendCString(char *buffer, size_t capacity, size_t *offset, const char *value) {
  if (value == NULL) {
    return NO;
  }
  size_t length = strlen(value);
  if (*offset + length + 1 > capacity) {
    return NO;
  }
  memcpy(buffer + *offset, value, length);
  *offset += length;
  buffer[*offset] = '\0';
  *offset += 1;
  return YES;
}

static NSString *KelivoStringFromOutputData(NSData *data) {
  NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (text != nil) {
    return text;
  }
  text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
  return text ?: @"";
}

static BOOL KelivoTarBlockIsEmpty(const unsigned char *block) {
  for (int i = 0; i < 512; i++) {
    if (block[i] != 0) {
      return NO;
    }
  }
  return YES;
}

static NSString *KelivoTarString(const unsigned char *field, size_t length) {
  size_t actualLength = 0;
  while (actualLength < length && field[actualLength] != '\0') {
    actualLength++;
  }
  if (actualLength == 0) {
    return @"";
  }
  return [[NSString alloc] initWithBytes:field length:actualLength encoding:NSUTF8StringEncoding] ?: @"";
}

static unsigned long long KelivoTarOctal(const unsigned char *field, size_t length) {
  unsigned long long value = 0;
  for (size_t i = 0; i < length; i++) {
    unsigned char c = field[i];
    if (c == '\0' || c == ' ') {
      continue;
    }
    if (c < '0' || c > '7') {
      break;
    }
    value = (value << 3) + (unsigned long long)(c - '0');
  }
  return value;
}

static NSString *_Nullable KelivoSanitizedTarPath(NSString *rawPath) {
  NSString *path = rawPath;
  while ([path hasPrefix:@"./"]) {
    path = [path substringFromIndex:2];
  }
  if (path.length == 0 || [path isEqualToString:@"."]) {
    return nil;
  }
  if ([path hasPrefix:@"/"]) {
    return nil;
  }
  for (NSString *component in [path componentsSeparatedByString:@"/"]) {
    if ([component isEqualToString:@".."]) {
      return nil;
    }
  }
  return path;
}

static BOOL KelivoEnsureParentDirectory(NSString *path, NSError **error) {
  NSString *parent = [path stringByDeletingLastPathComponent];
  if (parent.length == 0) {
    return YES;
  }
  return [NSFileManager.defaultManager createDirectoryAtPath:parent
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:error];
}

static FlutterError *_Nullable KelivoSkipGzBytes(gzFile file, unsigned long long length) {
  unsigned char buffer[32 * 1024];
  unsigned long long remaining = length;
  while (remaining > 0) {
    unsigned int chunk = (unsigned int)MIN((unsigned long long)sizeof(buffer), remaining);
    if (!KelivoGzReadFully(file, buffer, chunk)) {
      return KelivoTerminalError(@"runtime_unpack_failed", @"Terminal package ended while skipping tar entry data.", nil);
    }
    remaining -= chunk;
  }
  return nil;
}

static FlutterError *_Nullable KelivoUnpackRegularFile(gzFile file, NSString *path, unsigned long long size) {
  NSFileManager *fileManager = NSFileManager.defaultManager;
  NSError *error = nil;
  if (!KelivoEnsureParentDirectory(path, &error)) {
    return KelivoTerminalError(@"runtime_unpack_failed",
                               @"Terminal package parent directory could not be created.",
                               @{@"path" : path, @"error" : error.localizedDescription ?: @""});
  }
  [fileManager createFileAtPath:path contents:nil attributes:nil];
  NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
  if (handle == nil) {
    return KelivoTerminalError(@"runtime_unpack_failed", @"Terminal package file could not be created.", @{@"path" : path});
  }

  unsigned char buffer[32 * 1024];
  unsigned long long remaining = size;
  while (remaining > 0) {
    unsigned int chunk = (unsigned int)MIN((unsigned long long)sizeof(buffer), remaining);
    if (!KelivoGzReadFully(file, buffer, chunk)) {
      [handle closeFile];
      return KelivoTerminalError(@"runtime_unpack_failed", @"Terminal package ended while reading tar entry data.", @{@"path" : path});
    }
    NSData *data = [NSData dataWithBytes:buffer length:chunk];
    @try {
      [handle writeData:data];
    } @catch (NSException *exception) {
      [handle closeFile];
      return KelivoTerminalError(@"runtime_unpack_failed",
                                 @"Terminal package file could not be written.",
                                 @{@"path" : path, @"error" : exception.reason ?: @""});
    }
    remaining -= chunk;
  }
  [handle closeFile];
  return nil;
}

static FlutterError *_Nullable KelivoUnpackTarGz(NSString *archivePath, NSString *destinationPath) {
  gzFile file = gzopen(archivePath.fileSystemRepresentation, "rb");
  if (file == NULL) {
    return KelivoTerminalError(@"runtime_unpack_failed", @"Terminal package could not be opened.", @{@"path" : archivePath});
  }

  NSFileManager *fileManager = NSFileManager.defaultManager;
  unsigned char header[512];
  while (KelivoGzReadFully(file, header, sizeof(header))) {
    if (KelivoTarBlockIsEmpty(header)) {
      gzclose(file);
      return nil;
    }

    NSString *name = KelivoTarString(header, 100);
    NSString *prefix = KelivoTarString(header + 345, 155);
    NSString *rawPath = prefix.length > 0 ? [prefix stringByAppendingPathComponent:name] : name;
    NSString *relativePath = KelivoSanitizedTarPath(rawPath);
    unsigned long long size = KelivoTarOctal(header + 124, 12);
    unsigned long long mode = KelivoTarOctal(header + 100, 8);
    char type = (char)header[156];
    NSString *destination = relativePath == nil ? nil : [destinationPath stringByAppendingPathComponent:relativePath];

    FlutterError *entryError = nil;
    NSError *error = nil;
    if (destination != nil) {
      if (type == '5') {
        if (![fileManager createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:&error]) {
          entryError = KelivoTerminalError(@"runtime_unpack_failed",
                                           @"Terminal package directory could not be created.",
                                           @{@"path" : destination, @"error" : error.localizedDescription ?: @""});
        }
      } else if (type == '2') {
        NSString *linkTarget = KelivoTarString(header + 157, 100);
        if (!KelivoEnsureParentDirectory(destination, &error) ||
            ![fileManager createSymbolicLinkAtPath:destination withDestinationPath:linkTarget error:&error]) {
          entryError = KelivoTerminalError(@"runtime_unpack_failed",
                                           @"Terminal package symlink could not be created.",
                                           @{@"path" : destination, @"error" : error.localizedDescription ?: @""});
        }
      } else if (type == '\0' || type == '0') {
        entryError = KelivoUnpackRegularFile(file, destination, size);
        if (entryError == nil && mode > 0) {
          [fileManager setAttributes:@{NSFilePosixPermissions : @((NSUInteger)(mode & 0777))}
                        ofItemAtPath:destination
                               error:nil];
        }
      }
    }

    if (entryError != nil) {
      gzclose(file);
      return entryError;
    }

    if (!(type == '\0' || type == '0')) {
      entryError = KelivoSkipGzBytes(file, size);
      if (entryError != nil) {
        gzclose(file);
        return entryError;
      }
    }

    unsigned long long padding = (512 - (size % 512)) % 512;
    entryError = KelivoSkipGzBytes(file, padding);
    if (entryError != nil) {
      gzclose(file);
      return entryError;
    }
  }

  gzclose(file);
  return KelivoTerminalError(@"runtime_unpack_failed", @"Terminal package tar stream ended unexpectedly.", nil);
}

@interface KelivoOpenMinisTerminalHandle : NSObject
@property(nonatomic, nullable) NSString *sessionId;
@property(nonatomic) struct tty *tty;
@property(nonatomic) NSMutableData *pendingOutput;
@property(nonatomic) NSMutableData *capturedOutput;
@property(nonatomic) NSCondition *captureCondition;
@property(nonatomic) NSUInteger outputEvents;
@property(nonatomic) NSUInteger outputBytes;
@property(nonatomic) NSUInteger captureOutputLimit;
@property(nonatomic) BOOL captureOutput;
@property(nonatomic) BOOL captureTruncated;
@property(nonatomic) BOOL didLogFirstOutput;
@end

#if KELIVO_OPENMINIS_ISH
void KelivoOpenMinisDiagnostic(const char *message) {
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"openminis: %s", message ?: ""]);
}
#endif

@implementation KelivoOpenMinisTerminalHandle
- (instancetype)init {
  self = [super init];
  if (self) {
    _pendingOutput = [NSMutableData data];
    _capturedOutput = [NSMutableData data];
    _captureCondition = [NSCondition new];
  }
  return self;
}
@end

@interface KelivoOpenMinisSession : NSObject
@property(nonatomic) NSString *sessionId;
@property(nonatomic) KelivoOpenMinisTerminalHandle *terminal;
@property(nonatomic) int pid;
@property(nonatomic) NSUInteger inputEvents;
@property(nonatomic) NSUInteger inputBytes;
@end

@implementation KelivoOpenMinisSession
@end

static __weak KelivoOpenMinisRuntimeBridge *KelivoActiveBridge;
static NSString *KelivoDefaultRootPath;
static char *KelivoDefaultRootPathCString;
#endif

@interface KelivoOpenMinisRuntimeBridge ()
@property(nonatomic, copy, nullable) NSString *lastError;
@property(nonatomic) NSMutableArray<NSDictionary<NSString *, id> *> *pendingEvents;
@property(nonatomic) NSUInteger debugDrainCallsWithEvents;
@property(nonatomic) NSUInteger debugDrainOutputEvents;
@property(nonatomic) NSUInteger debugDrainOutputBytes;
#if KELIVO_OPENMINIS_ISH
@property(nonatomic) NSMutableDictionary<NSString *, KelivoOpenMinisSession *> *sessions;
@property(nonatomic) NSLock *installLock;
@property(nonatomic) NSLock *stateLock;
@property(nonatomic) BOOL booted;
@property(nonatomic) BOOL booting;
- (void)markKernelReady;
- (void)markKernelFailed:(NSString *)code message:(NSString *)message;
- (void)emit:(NSDictionary<NSString *, id> *)event;
#endif
@end

#if KELIVO_OPENMINIS_ISH
static int KelivoPtyInit(struct tty *tty) {
  KelivoOpenMinisTerminalHandle *terminal = [KelivoOpenMinisTerminalHandle new];
  terminal.tty = tty;
  tty->data = (void *)CFBridgingRetain(terminal);
  return 0;
}

static int KelivoPtyWrite(struct tty *tty, const void *buf, size_t len, bool blocking) {
  KelivoOpenMinisTerminalHandle *terminal = (__bridge KelivoOpenMinisTerminalHandle *)tty->data;
  if (terminal == nil) {
    return (int)len;
  }
  terminal.outputEvents += 1;
  terminal.outputBytes += len;
  if (!terminal.didLogFirstOutput) {
    terminal.didLogFirstOutput = YES;
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"KelivoPtyWrite first len=%zu blocking=%@", len, blocking ? @"yes" : @"no"]);
  }
  NSData *output = [NSData dataWithBytes:buf length:len];
  if (terminal.captureOutput) {
    [terminal.captureCondition lock];
    NSUInteger available = terminal.captureOutputLimit > terminal.capturedOutput.length
                               ? terminal.captureOutputLimit - terminal.capturedOutput.length
                               : 0;
    if (available > 0) {
      NSUInteger bytesToAppend = MIN(available, output.length);
      [terminal.capturedOutput appendData:[output subdataWithRange:NSMakeRange(0, bytesToAppend)]];
      if (bytesToAppend < output.length) {
        terminal.captureTruncated = YES;
      }
    } else {
      terminal.captureTruncated = YES;
    }
    [terminal.captureCondition signal];
    [terminal.captureCondition unlock];
    return (int)len;
  }
  if (terminal.sessionId.length == 0) {
    [terminal.pendingOutput appendData:output];
    return (int)len;
  }
  NSString *dataBase64 = [output base64EncodedStringWithOptions:0];
  [KelivoActiveBridge emit:@{
    @"type" : @"sessionOutput",
    @"sessionId" : terminal.sessionId,
    @"dataBase64" : dataBase64,
    @"byteLength" : @(len),
  }];
  return (int)len;
}

static void KelivoPtyCleanup(struct tty *tty) {
  if (tty->data != NULL) {
    CFBridgingRelease(tty->data);
    tty->data = NULL;
  }
}

static const struct tty_driver_ops KelivoPtyOps = {
    .init = KelivoPtyInit,
    .write = KelivoPtyWrite,
    .cleanup = KelivoPtyCleanup,
};

static struct tty_driver KelivoPtyDriver = {
    .ops = &KelivoPtyOps,
};

static void KelivoIshExitHook(struct task *task, int code) {
  pid_t pid = task == NULL ? 0 : task->pid;
  dispatch_async(dispatch_get_main_queue(), ^{
    KelivoOpenMinisRuntimeBridge *bridge = KelivoActiveBridge;
    if (bridge == nil) {
      return;
    }
    NSString *matchedSessionId = nil;
    @synchronized(bridge.sessions) {
      for (KelivoOpenMinisSession *session in bridge.sessions.allValues) {
        if (session.pid == pid) {
          matchedSessionId = session.sessionId;
          [bridge.sessions removeObjectForKey:session.sessionId];
          break;
        }
      }
    }
    if (matchedSessionId.length > 0) {
      [bridge emit:@{@"type" : @"sessionExit", @"sessionId" : matchedSessionId, @"code" : @(code)}];
    }
  });
}

static void KelivoIshDieHandler(const char *message) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [KelivoActiveBridge markKernelFailed:@"openminis_kernel_die" message:@(message ?: "")];
  });
}
#endif

@implementation KelivoOpenMinisRuntimeBridge

- (instancetype)init {
  self = [super init];
  if (self) {
    _pendingEvents = [NSMutableArray array];
#if KELIVO_OPENMINIS_ISH
    _sessions = [NSMutableDictionary dictionary];
    _installLock = [NSLock new];
    _stateLock = [NSLock new];
    KelivoActiveBridge = self;
#endif
  }
  return self;
}

- (NSDictionary<NSString *, id> *)runtimeStatus {
  NSString *rootPath = KelivoTerminalOpenMinisRootPath();
  BOOL isDirectory = NO;
  BOOL hasRoot = [NSFileManager.defaultManager fileExistsAtPath:rootPath isDirectory:&isDirectory] && isDirectory;
  NSDictionary *metadata = hasRoot ? KelivoTerminalRuntimeMetadata() : nil;
  NSString *lastError = self.lastError ?: KelivoTerminalLastError();

  return @{
    @"status" : hasRoot ? @"installed" : @"notInstalled",
#if KELIVO_OPENMINIS_ISH
    @"integrationStatus" : @"linked",
#else
    @"integrationStatus" : @"notLinked",
#endif
    @"runtimeId" : KelivoTerminalRuntimeId,
    @"version" : metadata[@"version"] ?: [NSNull null],
    @"integrationReference" : KelivoTerminalIntegrationReference,
    @"packageSource" : metadata[@"manifestUrl"] ?: KelivoTerminalPackageSource,
    @"rootfsBytes" : @(hasRoot ? KelivoDirectorySize(rootPath) : 0),
    @"homeBytes" : @(KelivoDirectorySize([KelivoTerminalSupportPath() stringByAppendingPathComponent:@"homes/default"])),
    @"cacheBytes" : @(KelivoDirectorySize([KelivoTerminalSupportPath() stringByAppendingPathComponent:@"cache"])),
    @"backupBytes" : @(KelivoDirectorySize([KelivoTerminalSupportPath() stringByAppendingPathComponent:@"backups"])),
    @"lastInstallOrUpdateTime" : metadata[@"installedAt"] ?: [NSNull null],
    @"lastError" : lastError.length > 0 ? lastError : (id)[NSNull null],
  };
}

- (NSDictionary<NSString *, id> *)diagnosticLog {
  NSString *path = KelivoTerminalLogPath();
  NSData *data = [NSData dataWithContentsOfFile:path];
  NSString *text = data == nil ? @"" : ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"");
  return @{
    @"path" : path,
    @"text" : text,
  };
}

- (void)appendDiagnosticWithArguments:(NSDictionary<NSString *, id> *)arguments {
  NSString *message = [self requiredString:arguments key:@"message"];
  if (message.length == 0) {
    message = @"appendDiagnostic";
  }
  KelivoTerminalAppendDiagnostic(message);
}

- (NSArray<NSDictionary<NSString *, id> *> *)drainEvents {
  @synchronized(self.pendingEvents) {
    NSArray<NSDictionary<NSString *, id> *> *events = [self.pendingEvents copy];
    [self.pendingEvents removeAllObjects];
    NSUInteger outputEvents = 0;
    NSUInteger outputBytes = 0;
    for (NSDictionary<NSString *, id> *event in events) {
      if ([event[@"type"] isEqualToString:@"sessionOutput"]) {
        outputEvents += 1;
        NSNumber *byteLength = event[@"byteLength"];
        outputBytes += byteLength.unsignedIntegerValue;
      }
    }
    if (events.count > 0) {
      self.debugDrainCallsWithEvents += 1;
      self.debugDrainOutputEvents += outputEvents;
      self.debugDrainOutputBytes += outputBytes;
      if (outputEvents == 0 ||
          self.debugDrainCallsWithEvents == 1 ||
          self.debugDrainCallsWithEvents == 10 ||
          self.debugDrainCallsWithEvents == 50) {
        KelivoTerminalAppendDiagnostic(
            [NSString stringWithFormat:@"drainEvents count=%lu outputEvents=%lu outputBytes=%lu totalOutputEvents=%lu totalOutputBytes=%lu",
                                       (unsigned long)events.count,
                                       (unsigned long)outputEvents,
                                       (unsigned long)outputBytes,
                                       (unsigned long)self.debugDrainOutputEvents,
                                       (unsigned long)self.debugDrainOutputBytes]);
      }
    }
    return events;
  }
}

- (FlutterError *_Nullable)installRuntimeWithArguments:(NSDictionary<NSString *, id> *)arguments {
#if !KELIVO_OPENMINIS_ISH
  return KelivoTerminalError(
      @"openminis_runtime_not_linked",
      @"OpenMinis iSH ARM64 is not linked into Runner.",
      @{@"method" : @"installRuntime"});
#else
  KelivoTerminalAppendDiagnostic(@"installRuntime requested");
  if (![self.installLock tryLock]) {
    return KelivoTerminalError(@"terminal_install_in_progress", @"Terminal runtime install is already running.", nil);
  }
  @try {
    if (self.sessions.count > 0 || self.booting || self.booted) {
      return KelivoTerminalError(@"terminal_sessions_active",
                                 @"Stop terminal sessions before installing the runtime.",
                                 nil);
    }

    NSString *manifestUrlText = [self requiredString:arguments key:@"manifestUrl"];
    if (manifestUrlText.length == 0) {
      manifestUrlText = KelivoTerminalPackageSource;
    }
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"installRuntime manifest=%@", manifestUrlText]);
    NSURL *manifestUrl = [NSURL URLWithString:manifestUrlText];
    if (manifestUrl == nil) {
      return KelivoTerminalError(@"invalid_manifest_url", @"Terminal manifest URL is invalid.", @{@"url" : manifestUrlText});
    }

    NSError *error = nil;
    NSData *manifestData = [NSData dataWithContentsOfURL:manifestUrl options:0 error:&error];
    if (manifestData == nil) {
      KelivoTerminalWriteLastError(@"manifest_download_failed");
      return KelivoTerminalError(@"manifest_download_failed",
                                 @"Terminal manifest download failed.",
                                 @{@"url" : manifestUrlText, @"error" : error.localizedDescription ?: @""});
    }

    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&error];
    if (![manifest isKindOfClass:NSDictionary.class]) {
      return KelivoTerminalError(@"manifest_parse_failed",
                                 @"Terminal manifest JSON is invalid.",
                                 @{@"error" : error.localizedDescription ?: @""});
    }

    NSNumber *schemaVersion = manifest[@"schemaVersion"];
    NSString *runtimeId = [self stringFromObject:manifest[@"runtimeId"]];
    NSString *version = [self stringFromObject:manifest[@"version"]];
    NSString *platform = [self stringFromObject:manifest[@"platform"]];
    NSString *arch = [self stringFromObject:manifest[@"arch"]];
    NSDictionary *package = manifest[@"package"];
    NSString *format = [self stringFromObject:package[@"format"]];
    NSString *packageUrlText = [self stringFromObject:package[@"url"]];
    NSString *expectedSha256 = [self stringFromObject:package[@"sha256"]].lowercaseString;
    KelivoTerminalAppendDiagnostic(
        [NSString stringWithFormat:@"installRuntime manifest runtimeId=%@ version=%@ package=%@",
                                   runtimeId,
                                   version,
                                   packageUrlText]);

    if (schemaVersion.intValue != 1 || ![runtimeId isEqualToString:KelivoTerminalRuntimeId] ||
        version.length == 0 || ![platform isEqualToString:@"ios"] || ![arch isEqualToString:@"arm64"] ||
        ![package isKindOfClass:NSDictionary.class] || ![format isEqualToString:@"tar.gz"] ||
        packageUrlText.length == 0 || expectedSha256.length != 64) {
      KelivoTerminalWriteLastError(@"manifest_validation_failed");
      return KelivoTerminalError(@"manifest_validation_failed", @"Terminal manifest does not match this runtime.", nil);
    }

    NSURL *packageUrl = [NSURL URLWithString:packageUrlText];
    if (packageUrl == nil) {
      return KelivoTerminalError(@"invalid_package_url", @"Terminal package URL is invalid.", @{@"url" : packageUrlText});
    }

    NSString *installId = NSUUID.UUID.UUIDString;
    NSString *supportPath = KelivoTerminalSupportPath();
    NSString *cachePath = [supportPath stringByAppendingPathComponent:@"cache/downloads"];
    NSString *stagingRoot = [[KelivoTerminalRuntimeBasePath() stringByAppendingPathComponent:@"staging"]
        stringByAppendingPathComponent:installId];
    NSString *packagePath = [cachePath stringByAppendingPathComponent:[installId stringByAppendingPathExtension:@"tar.gz"]];
    NSFileManager *fileManager = NSFileManager.defaultManager;

    if (![fileManager createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:&error]) {
      return KelivoTerminalError(@"cache_create_failed", @"Terminal installer cache could not be created.", @{@"error" : error.localizedDescription ?: @""});
    }
    [fileManager removeItemAtPath:stagingRoot error:nil];
    if (![fileManager createDirectoryAtPath:stagingRoot withIntermediateDirectories:YES attributes:nil error:&error]) {
      return KelivoTerminalError(@"staging_create_failed", @"Terminal staging directory could not be created.", @{@"error" : error.localizedDescription ?: @""});
    }

    NSData *packageData = [NSData dataWithContentsOfURL:packageUrl options:0 error:&error];
    if (packageData == nil || ![packageData writeToFile:packagePath options:NSDataWritingAtomic error:&error]) {
      [fileManager removeItemAtPath:stagingRoot error:nil];
      KelivoTerminalWriteLastError(@"package_download_failed");
      return KelivoTerminalError(@"package_download_failed",
                                 @"Terminal package download failed.",
                                 @{@"url" : packageUrlText, @"error" : error.localizedDescription ?: @""});
    }

    NSString *actualSha256 = KelivoSHA256ForFile(packagePath);
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"installRuntime package sha256=%@", actualSha256 ?: @""]);
    if (![actualSha256 isEqualToString:expectedSha256]) {
      [fileManager removeItemAtPath:stagingRoot error:nil];
      KelivoTerminalWriteLastError(@"package_sha256_mismatch");
      return KelivoTerminalError(@"package_sha256_mismatch",
                                 @"Terminal package checksum does not match the manifest.",
                                 @{@"expected" : expectedSha256, @"actual" : actualSha256 ?: @""});
    }

    FlutterError *unpackError = KelivoUnpackTarGz(packagePath, stagingRoot);
    if (unpackError != nil) {
      [fileManager removeItemAtPath:stagingRoot error:nil];
      KelivoTerminalWriteLastError(unpackError.code);
      return unpackError;
    }

    BOOL isDirectory = NO;
    NSString *dataPath = [stagingRoot stringByAppendingPathComponent:@"data"];
    NSString *metaPath = [stagingRoot stringByAppendingPathComponent:@"meta.db"];
    if (![fileManager fileExistsAtPath:dataPath isDirectory:&isDirectory] || !isDirectory ||
        ![fileManager fileExistsAtPath:metaPath isDirectory:&isDirectory] || isDirectory) {
      [fileManager removeItemAtPath:stagingRoot error:nil];
      KelivoTerminalWriteLastError(@"runtime_validation_failed");
      return KelivoTerminalError(@"runtime_validation_failed",
                                 @"Terminal package is missing required fakefs files.",
                                 @{@"data" : dataPath, @"meta" : metaPath});
    }

    NSString *currentPath = KelivoTerminalOpenMinisRootPath();
    NSString *metadataPath = [KelivoTerminalRuntimeBasePath() stringByAppendingPathComponent:@"metadata.json"];
    [fileManager createDirectoryAtPath:KelivoTerminalRuntimeBasePath() withIntermediateDirectories:YES attributes:nil error:nil];
    [fileManager removeItemAtPath:currentPath error:nil];
    if (![fileManager moveItemAtPath:stagingRoot toPath:currentPath error:&error]) {
      [fileManager removeItemAtPath:stagingRoot error:nil];
      KelivoTerminalWriteLastError(@"runtime_activation_failed");
      return KelivoTerminalError(@"runtime_activation_failed",
                                 @"Terminal runtime could not be activated.",
                                 @{@"error" : error.localizedDescription ?: @""});
    }

    NSISO8601DateFormatter *dateFormatter = [NSISO8601DateFormatter new];
    NSDictionary *metadata = @{
      @"runtimeId" : runtimeId,
      @"version" : version,
      @"installedAt" : [dateFormatter stringFromDate:NSDate.date],
      @"manifestUrl" : manifestUrlText,
      @"packageUrl" : packageUrlText,
      @"packageSha256" : expectedSha256,
      @"rootPath" : currentPath,
      @"status" : @"installed",
    };
    NSData *metadataData = [NSJSONSerialization dataWithJSONObject:metadata options:NSJSONWritingPrettyPrinted error:nil];
    [metadataData writeToFile:metadataPath atomically:YES];
    [fileManager removeItemAtPath:packagePath error:nil];
    [fileManager removeItemAtPath:KelivoTerminalLastErrorPath() error:nil];
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"installRuntime activated root=%@", currentPath]);
    [self emit:@{@"type" : @"runtimeInstalled", @"runtimeId" : runtimeId, @"version" : version}];
    return nil;
  } @finally {
    [self.installLock unlock];
  }
#endif
}

- (FlutterError *_Nullable)startSessionWithArguments:(NSDictionary<NSString *, id> *)arguments {
#if !KELIVO_OPENMINIS_ISH
  KelivoTerminalAppendDiagnostic(@"startSession failed: openminis_runtime_not_linked");
  return KelivoTerminalError(
      @"openminis_runtime_not_linked",
      @"The OpenMinis iSH ARM64 source is present, but its native runtime libraries are not linked into Runner yet.",
      @{@"method" : @"startSession"});
#else
  NSString *sessionId = [self requiredString:arguments key:@"sessionId"];
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession requested session=%@", sessionId]);
  if (sessionId.length == 0) {
    KelivoTerminalWriteLastError(@"invalid_args");
    return KelivoTerminalError(@"invalid_args", @"Missing sessionId.", nil);
  }
  if (self.sessions[sessionId] != nil) {
    KelivoTerminalWriteLastError(@"session_exists");
    return KelivoTerminalError(@"session_exists", @"Terminal session already exists.", @{@"sessionId" : sessionId});
  }

  FlutterError *bootError = [self bootIfNeeded];
  if (bootError != nil) {
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession deferred/failure code=%@", bootError.code]);
    return bootError;
  }

  NSString *shell = [self requiredString:arguments key:@"shell"];
  if (shell.length == 0) {
    shell = @"/bin/sh";
  }

  KelivoTerminalAppendDiagnostic(@"startSession entering ish do_execve");
  int retval = become_new_init_child();
  if (retval < 0) {
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession become_new_init_child failed=%d", retval]);
    KelivoTerminalWriteLastError(@"openminis_session_start_failed");
    return KelivoTerminalError(@"openminis_session_start_failed",
                               @"OpenMinis iSH failed to create the shell process.",
                               @{@"retval" : @(retval)});
  }

  struct tty *tty = pty_open_fake(&KelivoPtyDriver);
  if (IS_ERR(tty)) {
    retval = (int)PTR_ERR(tty);
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession pty_open_fake failed=%d", retval]);
    KelivoTerminalWriteLastError(@"openminis_session_start_failed");
    return KelivoTerminalError(@"openminis_session_start_failed",
                               @"OpenMinis iSH failed to create a pseudo terminal.",
                               @{@"retval" : @(retval)});
  }

  KelivoOpenMinisTerminalHandle *terminal = (__bridge KelivoOpenMinisTerminalHandle *)tty->data;
  NSString *stdioFile = [NSString stringWithFormat:@"/dev/pts/%d", tty->num];
  retval = create_stdio(stdioFile.fileSystemRepresentation, TTY_PSEUDO_SLAVE_MAJOR, tty->num);
  tty_release(tty);
  if (retval < 0) {
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession create_stdio failed=%d", retval]);
    KelivoTerminalWriteLastError(@"openminis_session_start_failed");
    return KelivoTerminalError(@"openminis_session_start_failed",
                               @"OpenMinis iSH failed to attach terminal stdio.",
                               @{@"retval" : @(retval)});
  }

  char argvBuffer[4096];
  memset(argvBuffer, 0, sizeof(argvBuffer));
  const char *shellPath = shell.UTF8String;
  size_t shellLength = strlen(shellPath);
  if (shellLength + 2 > sizeof(argvBuffer)) {
    KelivoTerminalWriteLastError(@"invalid_args");
    return KelivoTerminalError(@"invalid_args", @"Shell path is too long.", @{@"shell" : shell});
  }
  memcpy(argvBuffer, shellPath, shellLength);

  const char envpBuffer[] =
      "TERM=xterm-256color\0"
      "HOME=/root\0"
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\0"
      "PYTHONMALLOC=malloc\0"
      "\0";
  retval = do_execve(shellPath, 1, argvBuffer, envpBuffer);
  if (retval < 0) {
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession do_execve failed=%d shell=%@", retval, shell]);
    KelivoTerminalWriteLastError(@"openminis_session_start_failed");
    return KelivoTerminalError(@"openminis_session_start_failed",
                               @"OpenMinis iSH failed to execute the shell.",
                               @{@"retval" : @(retval), @"shell" : shell});
  }

  int pid = current->pid;
  terminal.sessionId = sessionId;
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession tty ready num=%d pendingBytes=%lu totalOutputEvents=%lu totalOutputBytes=%lu",
                                                            tty->num,
                                                            (unsigned long)terminal.pendingOutput.length,
                                                            (unsigned long)terminal.outputEvents,
                                                            (unsigned long)terminal.outputBytes]);
  KelivoOpenMinisSession *session = [KelivoOpenMinisSession new];
  session.sessionId = sessionId;
  session.pid = pid;
  session.terminal = terminal;
  @synchronized(self.sessions) {
    self.sessions[sessionId] = session;
  }
  [self flushPendingOutputForTerminal:terminal];
  task_start(current);
  [NSFileManager.defaultManager removeItemAtPath:KelivoTerminalLastErrorPath() error:nil];
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"startSession started session=%@ pid=%d", sessionId, pid]);
  [self emit:@{@"type" : @"sessionStarted", @"sessionId" : sessionId, @"pid" : @(pid)}];
  return nil;
#endif
}

- (FlutterError *_Nullable)writeSessionWithArguments:(NSDictionary<NSString *, id> *)arguments {
#if !KELIVO_OPENMINIS_ISH
  return KelivoTerminalError(@"openminis_runtime_not_linked", @"OpenMinis iSH ARM64 is not linked.", @{@"method" : @"writeSession"});
#else
  KelivoOpenMinisSession *session = [self sessionFromArguments:arguments];
  if (session == nil) {
    return KelivoTerminalError(@"session_not_found", @"Terminal session was not found.", @{@"sessionId" : arguments[@"sessionId"] ?: @""});
  }
  NSString *dataText = [self requiredString:arguments key:@"data"];
  NSData *data = [dataText dataUsingEncoding:NSUTF8StringEncoding];
  session.inputEvents += 1;
  session.inputBytes += data.length;
  if (session.inputEvents == 1 || session.inputEvents == 10 || session.inputEvents == 50) {
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"writeSession session=%@ bytes=%lu totalEvents=%lu totalBytes=%lu",
                                                              session.sessionId,
                                                              (unsigned long)data.length,
                                                              (unsigned long)session.inputEvents,
                                                              (unsigned long)session.inputBytes]);
  }
  struct tty *tty = session.terminal.tty;
  if (tty == NULL) {
    return KelivoTerminalError(@"session_tty_unavailable", @"Terminal session TTY is not available.", @{@"sessionId" : session.sessionId});
  }
  ssize_t written = tty_input(tty, data.bytes, data.length, false);
  if (session.inputEvents == 1 || session.inputEvents == 10 || session.inputEvents == 50 || written < 0) {
    KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"writeSession tty_input result=%zd", written]);
  }
  if (written < 0) {
    return KelivoTerminalError(@"terminal_input_failed",
                               @"OpenMinis iSH failed to send input to the terminal.",
                               @{@"sessionId" : session.sessionId, @"retval" : @((int)written)});
  }
  return nil;
#endif
}

- (FlutterError *_Nullable)resizeSessionWithArguments:(NSDictionary<NSString *, id> *)arguments {
#if !KELIVO_OPENMINIS_ISH
  return KelivoTerminalError(@"openminis_runtime_not_linked", @"OpenMinis iSH ARM64 is not linked.", @{@"method" : @"resizeSession"});
#else
  KelivoOpenMinisSession *session = [self sessionFromArguments:arguments];
  if (session == nil) {
    return KelivoTerminalError(@"session_not_found", @"Terminal session was not found.", @{@"sessionId" : arguments[@"sessionId"] ?: @""});
  }
  int cols = [arguments[@"cols"] intValue];
  int rows = [arguments[@"rows"] intValue];
  struct tty *tty = session.terminal.tty;
  if (cols <= 0 || rows <= 0) {
    return KelivoTerminalError(@"invalid_args", @"Terminal size must be positive.", nil);
  }
  if (tty == NULL) {
    return KelivoTerminalError(@"session_tty_unavailable", @"Terminal session TTY is not available.", @{@"sessionId" : session.sessionId});
  }
  lock(&tty->lock);
  tty_set_winsize(tty, (struct winsize_){.col = (word_t)cols, .row = (word_t)rows});
  unlock(&tty->lock);
  return nil;
#endif
}

- (FlutterError *_Nullable)stopSessionWithArguments:(NSDictionary<NSString *, id> *)arguments {
#if !KELIVO_OPENMINIS_ISH
  return KelivoTerminalError(@"openminis_runtime_not_linked", @"OpenMinis iSH ARM64 is not linked.", @{@"method" : @"stopSession"});
#else
  KelivoOpenMinisSession *session = [self sessionFromArguments:arguments];
  if (session == nil) {
    return nil;
  }
  struct tty *tty = session.terminal.tty;
  if (tty != NULL) {
    lock(&tty->lock);
    tty_hangup(tty);
    unlock(&tty->lock);
  }
  @synchronized(self.sessions) {
    [self.sessions removeObjectForKey:session.sessionId];
  }
  [self emit:@{@"type" : @"sessionExit", @"sessionId" : session.sessionId, @"code" : @"stopped"}];
  return nil;
#endif
}

- (id)runCommandWithArguments:(NSDictionary<NSString *, id> *)arguments {
#if !KELIVO_OPENMINIS_ISH
  return KelivoTerminalError(@"openminis_runtime_not_linked", @"OpenMinis iSH ARM64 is not linked.", @{@"method" : @"runCommand"});
#else
  NSString *command = [self requiredString:arguments key:@"command"];
  if (command.length == 0) {
    return KelivoTerminalError(@"invalid_args", @"Missing command.", nil);
  }

  NSTimeInterval timeout = [arguments[@"timeoutSeconds"] respondsToSelector:@selector(doubleValue)]
                                ? [arguments[@"timeoutSeconds"] doubleValue]
                                : 20.0;
  if (timeout < 1.0) timeout = 1.0;
  if (timeout > 120.0) timeout = 120.0;
  NSUInteger maxOutputBytes = [arguments[@"maxOutputBytes"] respondsToSelector:@selector(unsignedIntegerValue)]
                                  ? [arguments[@"maxOutputBytes"] unsignedIntegerValue]
                                  : 65536;
  if (maxOutputBytes < 1024) maxOutputBytes = 1024;
  if (maxOutputBytes > 1024 * 1024) maxOutputBytes = 1024 * 1024;

  FlutterError *bootError = [self bootIfNeeded];
  if (bootError != nil) {
    return bootError;
  }

  NSString *marker = [NSString stringWithFormat:@"__KELIVO_EXIT_%@__:", NSUUID.UUID.UUIDString];
  NSString *wrappedCommand = [NSString stringWithFormat:@"stty -echo -onlcr 2>/dev/null\n%@\nkelivo_rc=$?\nprintf '%@%%s\\n' \"$kelivo_rc\"\n",
                                                        command,
                                                        marker];
  const char *shellPath = "/bin/sh";
  const char *wrappedCString = wrappedCommand.UTF8String;
  if (wrappedCString == NULL) {
    return KelivoTerminalError(@"invalid_args", @"Command could not be encoded as UTF-8.", nil);
  }

  KelivoTerminalAppendDiagnostic(@"runCommand entering ish do_execve");
  int retval = become_new_init_child();
  if (retval < 0) {
    return KelivoTerminalError(@"openminis_command_start_failed",
                               @"OpenMinis iSH failed to create the command process.",
                               @{@"retval" : @(retval)});
  }

  struct tty *tty = pty_open_fake(&KelivoPtyDriver);
  if (IS_ERR(tty)) {
    retval = (int)PTR_ERR(tty);
    return KelivoTerminalError(@"openminis_command_start_failed",
                               @"OpenMinis iSH failed to create a command pseudo terminal.",
                               @{@"retval" : @(retval)});
  }

  KelivoOpenMinisTerminalHandle *terminal = (__bridge KelivoOpenMinisTerminalHandle *)tty->data;
  terminal.captureOutput = YES;
  terminal.captureOutputLimit = maxOutputBytes + marker.length + 32;

  NSString *stdioFile = [NSString stringWithFormat:@"/dev/pts/%d", tty->num];
  retval = create_stdio(stdioFile.fileSystemRepresentation, TTY_PSEUDO_SLAVE_MAJOR, tty->num);
  tty_release(tty);
  if (retval < 0) {
    return KelivoTerminalError(@"openminis_command_start_failed",
                               @"OpenMinis iSH failed to attach command stdio.",
                               @{@"retval" : @(retval)});
  }

  char argvBuffer[65536];
  memset(argvBuffer, 0, sizeof(argvBuffer));
  size_t argvOffset = 0;
  if (!KelivoAppendCString(argvBuffer, sizeof(argvBuffer), &argvOffset, shellPath) ||
      !KelivoAppendCString(argvBuffer, sizeof(argvBuffer), &argvOffset, "-lc") ||
      !KelivoAppendCString(argvBuffer, sizeof(argvBuffer), &argvOffset, wrappedCString)) {
    return KelivoTerminalError(@"invalid_args", @"Command is too long.", nil);
  }

  const char envpBuffer[] =
      "TERM=xterm-256color\0"
      "HOME=/root\0"
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\0"
      "PYTHONMALLOC=malloc\0"
      "\0";
  retval = do_execve(shellPath, 3, argvBuffer, envpBuffer);
  if (retval < 0) {
    return KelivoTerminalError(@"openminis_command_start_failed",
                               @"OpenMinis iSH failed to execute the command shell.",
                               @{@"retval" : @(retval)});
  }

  task_start(current);

  NSData *markerData = [marker dataUsingEncoding:NSUTF8StringEncoding] ?: NSData.data;
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  NSData *captured = nil;
  NSRange markerRange = NSMakeRange(NSNotFound, 0);
  while (NSDate.date.timeIntervalSince1970 < deadline.timeIntervalSince1970) {
    [terminal.captureCondition lock];
    captured = [terminal.capturedOutput copy];
    markerRange = [captured rangeOfData:markerData options:0 range:NSMakeRange(0, captured.length)];
    if (markerRange.location != NSNotFound) {
      [terminal.captureCondition unlock];
      break;
    }
    [terminal.captureCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    [terminal.captureCondition unlock];
  }
  [terminal.captureCondition lock];
  captured = [terminal.capturedOutput copy];
  markerRange = [captured rangeOfData:markerData options:0 range:NSMakeRange(0, captured.length)];
  BOOL truncated = terminal.captureTruncated;
  [terminal.captureCondition unlock];

  if (tty != NULL) {
    lock(&tty->lock);
    tty_hangup(tty);
    unlock(&tty->lock);
  }

  if (markerRange.location == NSNotFound) {
    return KelivoTerminalError(@"terminal_command_timeout",
                               @"Terminal command timed out before completion.",
                               @{@"timeoutSeconds" : @(timeout), @"truncated" : @(truncated)});
  }

  NSData *outputData = [captured subdataWithRange:NSMakeRange(0, markerRange.location)];
  NSUInteger exitStart = markerRange.location + markerRange.length;
  NSUInteger exitEnd = exitStart;
  const unsigned char *bytes = captured.bytes;
  while (exitEnd < captured.length && bytes[exitEnd] != '\n' && bytes[exitEnd] != '\r') {
    exitEnd++;
  }
  NSData *exitData = [captured subdataWithRange:NSMakeRange(exitStart, exitEnd - exitStart)];
  NSString *exitText = [[NSString alloc] initWithData:exitData encoding:NSUTF8StringEncoding] ?: @"-1";
  NSInteger exitCode = exitText.integerValue;
  NSString *output = KelivoStringFromOutputData(outputData);
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"runCommand completed exit=%ld bytes=%lu truncated=%@",
                                                            (long)exitCode,
                                                            (unsigned long)outputData.length,
                                                            truncated ? @"yes" : @"no"]);
  return @{
    @"output" : output,
    @"exitCode" : @(exitCode),
    @"timedOut" : @NO,
    @"truncated" : @(truncated),
  };
#endif
}

- (NSString *)requiredString:(NSDictionary<NSString *, id> *)arguments key:(NSString *)key {
  id value = arguments[key];
  if ([value isKindOfClass:NSString.class]) {
    return (NSString *)value;
  }
  return @"";
}

- (NSString *)stringFromObject:(id)value {
  if ([value isKindOfClass:NSString.class]) {
    return (NSString *)value;
  }
  if ([value respondsToSelector:@selector(stringValue)]) {
    return [value stringValue];
  }
  return @"";
}

- (void)emit:(NSDictionary<NSString *, id> *)event {
  @synchronized(self.pendingEvents) {
    [self.pendingEvents addObject:event];
    if (self.pendingEvents.count > 500) {
      [self.pendingEvents removeObjectsInRange:NSMakeRange(0, self.pendingEvents.count - 500)];
    }
  }
}

#if KELIVO_OPENMINIS_ISH
- (FlutterError *_Nullable)bootIfNeeded {
  [self.stateLock lock];
  if (self.booted) {
    [self.stateLock unlock];
    KelivoTerminalAppendDiagnostic(@"bootIfNeeded already ready");
    return nil;
  }
  if (self.booting) {
    [self.stateLock unlock];
    return KelivoTerminalError(@"terminal_kernel_booting",
                               @"OpenMinis iSH kernel is still booting.",
                               nil);
  }
  [self.stateLock unlock];

  NSString *rootPath = KelivoTerminalOpenMinisRootPath();
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"bootIfNeeded root=%@", rootPath]);
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:rootPath isDirectory:&isDirectory] || !isDirectory) {
    KelivoTerminalWriteLastError(@"runtime_not_installed");
    return KelivoTerminalError(@"runtime_not_installed",
                               @"OpenMinis iSH rootfs is missing.",
                               @{@"rootPath" : rootPath});
  }
  NSString *dataPath = [rootPath stringByAppendingPathComponent:@"data"];
  NSString *metaPath = [rootPath stringByAppendingPathComponent:@"meta.db"];
  BOOL dataIsDirectory = NO;
  BOOL hasData = [NSFileManager.defaultManager fileExistsAtPath:dataPath isDirectory:&dataIsDirectory] && dataIsDirectory;
  BOOL metaIsDirectory = NO;
  BOOL hasMeta = [NSFileManager.defaultManager fileExistsAtPath:metaPath isDirectory:&metaIsDirectory] && !metaIsDirectory;
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"bootIfNeeded fakefs data=%@ meta=%@",
                                                            hasData ? @"yes" : @"no",
                                                            hasMeta ? @"yes" : @"no"]);
  if (!hasData || !hasMeta) {
    KelivoTerminalWriteLastError(@"runtime_validation_failed");
    return KelivoTerminalError(@"runtime_validation_failed",
                               @"OpenMinis iSH fakefs files are missing.",
                               @{@"data" : dataPath, @"meta" : metaPath});
  }

  [self.stateLock lock];
  if (self.booted) {
    [self.stateLock unlock];
    return nil;
  }
  if (self.booting) {
    [self.stateLock unlock];
    return KelivoTerminalError(@"terminal_kernel_booting",
                               @"OpenMinis iSH kernel is still booting.",
                               nil);
  }
  KelivoDefaultRootPath = rootPath;
  free(KelivoDefaultRootPathCString);
  const char *rootPathCString = rootPath.fileSystemRepresentation;
  KelivoDefaultRootPathCString = rootPathCString == NULL ? NULL : strdup(rootPathCString);
  if (KelivoDefaultRootPathCString == NULL) {
    [self.stateLock unlock];
    KelivoTerminalWriteLastError(@"terminal_root_path_failed");
    return KelivoTerminalError(@"terminal_root_path_failed",
                               @"OpenMinis iSH root path could not be prepared.",
                               @{@"rootPath" : rootPath});
  }
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"bootIfNeeded root cstring prepared length=%zu",
                                                            strlen(KelivoDefaultRootPathCString)]);
  self.booting = YES;
  self.lastError = nil;
  [self.stateLock unlock];

  NSString *fakefsDataPath = [rootPath stringByAppendingPathComponent:@"data"];
  int err = mount_root(&fakefs, fakefsDataPath.fileSystemRepresentation);
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"bootIfNeeded mount_root result=%d", err]);
  if (err < 0) {
    [self markKernelFailed:@"terminal_mount_root_failed" message:[NSString stringWithFormat:@"OpenMinis iSH mount_root failed: %d", err]];
    return KelivoTerminalError(@"terminal_mount_root_failed",
                               @"OpenMinis iSH failed to mount the fakefs root.",
                               @{@"retval" : @(err), @"rootPath" : rootPath});
  }

  err = become_first_process();
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"bootIfNeeded become_first_process result=%d", err]);
  if (err < 0) {
    [self markKernelFailed:@"terminal_kernel_boot_failed" message:[NSString stringWithFormat:@"OpenMinis iSH become_first_process failed: %d", err]];
    return KelivoTerminalError(@"terminal_kernel_boot_failed",
                               @"OpenMinis iSH failed to create the init process.",
                               @{@"retval" : @(err)});
  }

  generic_mkdirat(AT_PWD, "/dev", 0755);
  generic_mkdirat(AT_PWD, "/dev/pts", 0755);
  generic_mkdirat(AT_PWD, "/proc", 0755);
  generic_mknodat(AT_PWD, "/dev/tty", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_TTY_MINOR));
  generic_mknodat(AT_PWD, "/dev/console", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_CONSOLE_MINOR));
  generic_mknodat(AT_PWD, "/dev/ptmx", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_PTMX_MINOR));
  generic_mknodat(AT_PWD, "/dev/null", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_NULL_MINOR));
  generic_mknodat(AT_PWD, "/dev/zero", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_ZERO_MINOR));
  generic_mknodat(AT_PWD, "/dev/full", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_FULL_MINOR));
  generic_mknodat(AT_PWD, "/dev/random", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_RANDOM_MINOR));
  generic_mknodat(AT_PWD, "/dev/urandom", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_URANDOM_MINOR));
  do_mount(&procfs, "proc", "/proc", "", 0);
  do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);
  exit_hook = KelivoIshExitHook;
  die_handler = KelivoIshDieHandler;

  [self markKernelReady];
  return nil;
}

- (KelivoOpenMinisSession *_Nullable)sessionFromArguments:(NSDictionary<NSString *, id> *)arguments {
  NSString *sessionId = [self requiredString:arguments key:@"sessionId"];
  if (sessionId.length == 0) {
    return nil;
  }
  @synchronized(self.sessions) {
    return self.sessions[sessionId];
  }
}

- (void)flushPendingOutputForTerminal:(KelivoOpenMinisTerminalHandle *)terminal {
  if (terminal.sessionId.length == 0 || terminal.pendingOutput.length == 0) {
    return;
  }
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"flushPendingOutput bytes=%lu", (unsigned long)terminal.pendingOutput.length]);
  NSString *dataBase64 = [terminal.pendingOutput base64EncodedStringWithOptions:0];
  NSUInteger byteLength = terminal.pendingOutput.length;
  [terminal.pendingOutput setLength:0];
  [self emit:@{
    @"type" : @"sessionOutput",
    @"sessionId" : terminal.sessionId,
    @"dataBase64" : dataBase64,
    @"byteLength" : @(byteLength),
  }];
}

- (void)markKernelReady {
  [self.stateLock lock];
  self.booted = YES;
  self.booting = NO;
  self.lastError = nil;
  [self.stateLock unlock];
  [NSFileManager.defaultManager removeItemAtPath:KelivoTerminalLastErrorPath() error:nil];
  KelivoTerminalAppendDiagnostic(@"kernel ready");
  [self emit:@{@"type" : @"runtimeKernelReady"}];
}

- (void)markKernelFailed:(NSString *)code message:(NSString *)message {
  [self.stateLock lock];
  self.booting = NO;
  self.booted = NO;
  self.lastError = code;
  [self.stateLock unlock];
  KelivoTerminalWriteLastError(code);
  KelivoTerminalAppendDiagnostic([NSString stringWithFormat:@"kernel failed code=%@ message=%@", code, message]);
  [self emit:@{@"type" : @"sessionError", @"code" : code, @"message" : message}];
}
#endif

@end
