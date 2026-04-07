const std = @import("std");

// ObjC runtime types and functions.

const id = *opaque {};
const SEL = *opaque {};
const Class = *opaque {};
const BOOL = i8;
const NSUInteger = usize;
const CGFloat = f64;

const NSBackingStoreBuffered: NSUInteger = 2;

const NSWindowStyleMaskTitled: NSUInteger = 1 << 0;
const NSWindowStyleMaskClosable: NSUInteger = 1 << 1;
const NSWindowStyleMaskMiniaturizable: NSUInteger = 1 << 2;
const NSWindowStyleMaskResizable: NSUInteger = 1 << 3;

const NSWindowStyleMaskDefault: NSUInteger =
    NSWindowStyleMaskTitled |
    NSWindowStyleMaskClosable |
    NSWindowStyleMaskMiniaturizable |
    NSWindowStyleMaskResizable;

const CGRect = extern struct {
    origin: CGPoint,
    size: CGSize,
};

const CGPoint = extern struct {
    x: CGFloat,
    y: CGFloat,
};

const CGSize = extern struct {
    width: CGFloat,
    height: CGFloat,
};

extern "c" fn objc_msgSend() void;
extern "c" fn objc_getClass(name: [*:0]const u8) ?Class;
extern "c" fn sel_registerName(name: [*:0]const u8) SEL;
extern "c" fn objc_allocateClassPair(superclass: Class, name: [*:0]const u8, extra_bytes: usize) ?Class;
extern "c" fn objc_registerClassPair(cls: Class) void;
extern "c" fn class_addMethod(cls: Class, name: SEL, imp: *const anyopaque, types: [*:0]const u8) BOOL;

fn msgSend(comptime ReturnType: type, receiver: anytype, sel_name: [*:0]const u8, args: anytype) ReturnType {
    const sel = sel_registerName(sel_name);
    const Args = @TypeOf(args);
    const args_info = @typeInfo(Args).@"struct".fields;

    const FnType = switch (args_info.len) {
        0 => *const fn (@TypeOf(receiver), SEL) callconv(.c) ReturnType,
        1 => *const fn (@TypeOf(receiver), SEL, args_info[0].type) callconv(.c) ReturnType,
        2 => *const fn (@TypeOf(receiver), SEL, args_info[0].type, args_info[1].type) callconv(.c) ReturnType,
        3 => *const fn (@TypeOf(receiver), SEL, args_info[0].type, args_info[1].type, args_info[2].type) callconv(.c) ReturnType,
        4 => *const fn (@TypeOf(receiver), SEL, args_info[0].type, args_info[1].type, args_info[2].type, args_info[3].type) callconv(.c) ReturnType,
        5 => *const fn (@TypeOf(receiver), SEL, args_info[0].type, args_info[1].type, args_info[2].type, args_info[3].type, args_info[4].type) callconv(.c) ReturnType,
        else => @compileError("too many arguments"),
    };

    const func: FnType = @ptrCast(&objc_msgSend);

    return switch (args_info.len) {
        0 => func(receiver, sel),
        1 => func(receiver, sel, args[0]),
        2 => func(receiver, sel, args[0], args[1]),
        3 => func(receiver, sel, args[0], args[1], args[2]),
        4 => func(receiver, sel, args[0], args[1], args[2], args[3]),
        5 => func(receiver, sel, args[0], args[1], args[2], args[3], args[4]),
        else => unreachable,
    };
}

fn getClass(name: [*:0]const u8) Class {
    return objc_getClass(name) orelse @panic("class not found");
}

fn alloc(class: Class) id {
    return msgSend(id, class, "alloc", .{});
}

fn nsString(str: [*:0]const u8) id {
    return msgSend(id, getClass("NSString"), "stringWithUTF8String:", .{str});
}

fn nsUrl(str: [*:0]const u8) id {
    return msgSend(id, getClass("NSURL"), "URLWithString:", .{nsString(str)});
}

pub const WebView = struct {
    window: id = undefined,
    webview: id = undefined,
    app: id = undefined,
    delegate: id = undefined,
    manager: id = undefined,
    should_terminate: bool = false,
    callback: ?*const fn ([]const u8) void = null,

    pub const Options = struct {
        title: [*:0]const u8 = "zuil",
        width: CGFloat = 800,
        height: CGFloat = 600,
        url: ?[*:0]const u8 = null,
        html: ?[*:0]const u8 = null,
        callback: ?*const fn ([]const u8) void = null,
    };

    pub fn init(self: *WebView, opts: Options) void {
        self.callback = opts.callback;

        // NSApplication setup.
        self.app = msgSend(id, getClass("NSApplication"), "sharedApplication", .{});
        msgSend(void, self.app, "setActivationPolicy:", .{@as(NSUInteger, 0)});

        // Create app delegate to handle applicationShouldTerminateAfterLastWindowClosed.
        self.delegate = createAppDelegate(self);
        msgSend(void, self.app, "setDelegate:", .{self.delegate});

        // WKWebView configuration.
        const config = msgSend(id, alloc(getClass("WKWebViewConfiguration")), "init", .{});
        self.manager = msgSend(id, config, "userContentController", .{});

        // Register JS bridge handler.
        const handler = createScriptHandler(self);
        msgSend(void, self.manager, "addScriptMessageHandler:name:", .{ handler, nsString("zuil") });

        // Inject bridge script so JS can call window.zuil.postMessage(msg).
        const bridge_source = nsString(
            "window.zuil = { postMessage: function(msg) { window.webkit.messageHandlers.zuil.postMessage(msg); } };",
        );
        const script = msgSend(
            id,
            alloc(getClass("WKUserScript")),
            "initWithSource:injectionTime:forMainFrameOnly:",
            .{ bridge_source, @as(NSUInteger, 0), @as(BOOL, 1) },
        );
        msgSend(void, self.manager, "addUserScript:", .{script});

        // Create WKWebView.
        const rect = CGRect{
            .origin = .{ .x = 0, .y = 0 },
            .size = .{ .width = opts.width, .height = opts.height },
        };
        self.webview = msgSend(
            id,
            alloc(getClass("WKWebView")),
            "initWithFrame:configuration:",
            .{ rect, config },
        );

        // Create NSWindow.
        self.window = msgSend(
            id,
            alloc(getClass("NSWindow")),
            "initWithContentRect:styleMask:backing:defer:",
            .{ rect, NSWindowStyleMaskDefault, NSBackingStoreBuffered, @as(BOOL, 0) },
        );
        msgSend(void, self.window, "setTitle:", .{nsString(opts.title)});
        msgSend(void, self.window, "setContentView:", .{self.webview});
        msgSend(void, self.window, "center", .{});

        // Load content.
        if (opts.url) |url| {
            const nsurl = nsUrl(url);
            const request = msgSend(id, getClass("NSURLRequest"), "requestWithURL:", .{nsurl});
            msgSend(void, self.webview, "loadRequest:", .{request});
        } else if (opts.html) |html| {
            msgSend(void, self.webview, "loadHTMLString:baseURL:", .{ nsString(html), @as(?id, null) });
        }
    }

    pub fn run(self: *WebView) void {
        msgSend(void, self.window, "makeKeyAndOrderFront:", .{@as(?id, null)});
        msgSend(void, self.app, "activateIgnoringOtherApps:", .{@as(BOOL, 1)});
        msgSend(void, self.app, "run", .{});
    }

    pub fn eval(self: *WebView, js: [*:0]const u8) void {
        msgSend(void, self.webview, "evaluateJavaScript:completionHandler:", .{ nsString(js), @as(?id, null) });
    }

    pub fn setTitle(self: *WebView, title: [*:0]const u8) void {
        msgSend(void, self.window, "setTitle:", .{nsString(title)});
    }

    pub fn setHtml(self: *WebView, html: [*:0]const u8) void {
        msgSend(void, self.webview, "loadHTMLString:baseURL:", .{ nsString(html), @as(?id, null) });
    }

    pub fn navigate(self: *WebView, url: [*:0]const u8) void {
        const nsurl = nsUrl(url);
        const request = msgSend(id, getClass("NSURLRequest"), "requestWithURL:", .{nsurl});
        msgSend(void, self.webview, "loadRequest:", .{request});
    }

    pub fn terminate(self: *WebView) void {
        msgSend(void, self.app, "terminate:", .{@as(?id, null)});
    }

    // Creates an ObjC class at runtime that implements
    // WKScriptMessageHandler to receive JS messages.
    fn createScriptHandler(self: *WebView) id {
        Instance.current = self;

        const cls = registerClass("ZuilScriptHandler", &.{
            .{
                .name = "userContentController:didReceiveScriptMessage:",
                .imp = @ptrCast(&scriptMessageHandler),
                .types = "v@:@@",
            },
        });

        return msgSend(id, alloc(cls), "init", .{});
    }

    fn createAppDelegate(self: *WebView) id {
        _ = self;

        const cls = registerClass("ZuilAppDelegate", &.{
            .{
                .name = "applicationShouldTerminateAfterLastWindowClosed:",
                .imp = @ptrCast(&appDelegateShouldTerminate),
                .types = "c@:@",
            },
        });

        return msgSend(id, alloc(cls), "init", .{});
    }

    const MethodDesc = struct {
        name: [*:0]const u8,
        imp: *const anyopaque,
        types: [*:0]const u8,
    };

    fn registerClass(name: [*:0]const u8, methods: []const MethodDesc) Class {
        const superclass = getClass("NSObject");
        const cls = objc_allocateClassPair(superclass, name, 0) orelse
            return getClass(name);

        for (methods) |m| {
            _ = class_addMethod(cls, sel_registerName(m.name), m.imp, m.types);
        }
        objc_registerClassPair(cls);
        return cls;
    }
};

// Singleton instance pointer for the script handler callback.
// For multi-window support this would need associated objects or ivar storage.
const Instance = struct {
    var current: ?*WebView = null;
};

fn scriptMessageHandler(_: id, _: SEL, _: id, msg: id) callconv(.c) void {
    const wv = Instance.current orelse return;
    const cb = wv.callback orelse return;
    const body = msgSend(id, msg, "body", .{});
    const utf8 = msgSend([*:0]const u8, body, "UTF8String", .{});
    cb(std.mem.span(utf8));
}

fn appDelegateShouldTerminate(_: id, _: SEL, _: id) callconv(.c) BOOL {
    return 1;
}
