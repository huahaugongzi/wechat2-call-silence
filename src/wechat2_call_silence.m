#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <stdio.h>

static IMP originalOrderFront;
static IMP originalOrderFrontRegardless;
static IMP originalMakeKeyAndOrderFront;
static IMP originalOrderWindow;

static void LogCallWindow(NSWindow *window, NSString *path) {
    FILE *file = fopen("/private/tmp/wechat2_call_silence.log", "a");
    if (!file) return;
    NSString *line = [NSString stringWithFormat:@"%@ %@ class=%@ level=%ld frame=%@\n",
        [NSDate date], path, NSStringFromClass(window.class), (long)window.level,
        NSStringFromRect(window.frame)];
    fputs(line.UTF8String, file);
    fclose(file);
}

static BOOL IsIncomingCallPanel(NSWindow *window) {
    if (!window || window.level != NSModalPanelWindowLevel) return NO;
    NSRect frame = window.frame;
    return frame.size.width >= 240 && frame.size.width <= 380 &&
           frame.size.height >= 60 && frame.size.height <= 160;
}

static void HideCallPanel(NSWindow *window, NSString *path) {
    LogCallWindow(window, path);
    [window orderOut:nil];
}

static void FilterOrderFront(id self, SEL command, id sender) {
    NSWindow *window = self;
    if (IsIncomingCallPanel(window)) {
        HideCallPanel(window, @"orderFront");
        return;
    }
    ((void (*)(id, SEL, id))originalOrderFront)(self, command, sender);
}

static void FilterOrderFrontRegardless(id self, SEL command) {
    NSWindow *window = self;
    if (IsIncomingCallPanel(window)) {
        HideCallPanel(window, @"orderFrontRegardless");
        return;
    }
    ((void (*)(id, SEL))originalOrderFrontRegardless)(self, command);
}

static void FilterMakeKeyAndOrderFront(id self, SEL command, id sender) {
    NSWindow *window = self;
    if (IsIncomingCallPanel(window)) {
        HideCallPanel(window, @"makeKeyAndOrderFront");
        return;
    }
    ((void (*)(id, SEL, id))originalMakeKeyAndOrderFront)(self, command, sender);
}

static void FilterOrderWindow(id self, SEL command, NSWindowOrderingMode mode, NSInteger relative) {
    if (mode != NSWindowOut && IsIncomingCallPanel(self)) {
        LogCallWindow(self, @"blocked-before-orderWindow");
        ((void (*)(id, SEL, NSWindowOrderingMode, NSInteger))originalOrderWindow)
            (self, command, NSWindowOut, relative);
        return;
    }
    ((void (*)(id, SEL, NSWindowOrderingMode, NSInteger))originalOrderWindow)
        (self, command, mode, relative);
}

static void ScanVisibleWindows(void) {
    for (NSWindow *window in NSApp.windows) {
        if (window.isVisible && IsIncomingCallPanel(window)) {
            HideCallPanel(window, @"scan");
        }
    }
}

__attribute__((constructor)) static void InitializeCallSilence(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (![bundleID isEqualToString:@"com.tencent.xinWeChat.copy"]) return;
    FILE *file = fopen("/private/tmp/wechat2_call_silence.log", "a");
    if (file) { fputs("wechat2-call-silence loaded for com.tencent.xinWeChat.copy\n", file); fclose(file); }

    Class windowClass = NSWindow.class;
    Method method = class_getInstanceMethod(windowClass, @selector(orderFront:));
    if (method) originalOrderFront = method_setImplementation(method, (IMP)FilterOrderFront);
    method = class_getInstanceMethod(windowClass, @selector(orderFrontRegardless));
    if (method) originalOrderFrontRegardless = method_setImplementation(method, (IMP)FilterOrderFrontRegardless);
    method = class_getInstanceMethod(windowClass, @selector(makeKeyAndOrderFront:));
    if (method) originalMakeKeyAndOrderFront = method_setImplementation(method, (IMP)FilterMakeKeyAndOrderFront);
    method = class_getInstanceMethod(windowClass, @selector(orderWindow:relativeTo:));
    if (method) originalOrderWindow = method_setImplementation(method, (IMP)FilterOrderWindow);

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(__unused NSTimer *timer) {
            ScanVisibleWindows();
        }];
    });
}
