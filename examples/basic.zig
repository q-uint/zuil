const std = @import("std");
const zuil = @import("zuil");

pub fn main() void {
    var wv: zuil.WebView = .{};
    wv.init(.{
        .title = "ZUIL Example",
        .width = 1024,
        .height = 768,
        .html =
        \\<!DOCTYPE html>
        \\<html>
        \\<body style="font-family: system-ui; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0;">
        \\  <div style="text-align: center;">
        \\    <h1>ZUIL</h1>
        \\    <p>Pure Zig WebView</p>
        \\    <button onclick="zuil.postMessage('hello from JS')">Send message to Zig</button>
        \\    <pre id="log"></pre>
        \\  </div>
        \\</body>
        \\</html>
        ,
        .callback = &onMessage,
    });
    wv.run();
}

fn onMessage(msg: []const u8) void {
    std.debug.print("JS says: {s}\n", .{msg});
}
