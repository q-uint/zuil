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
        \\    <p id="tick"></p>
        \\    <pre id="log"></pre>
        \\  </div>
        \\</body>
        \\</html>
        ,
        .callback = &onMessage,
    });

    // Background thread updating the UI via dispatchEval.
    const t = std.Thread.spawn(.{}, backgroundTick, .{&wv}) catch return;
    t.detach();

    wv.run();
}

fn backgroundTick(wv: *zuil.WebView) void {
    var count: u32 = 0;
    while (true) {
        std.Thread.sleep(1_000_000_000);
        count += 1;
        var buf: [128]u8 = undefined;
        const js = std.fmt.bufPrintZ(&buf, "document.getElementById('tick').textContent='Background Tick: {d}';", .{count}) catch continue;
        wv.dispatchEvaluateJs(js);
    }
}

fn onMessage(msg: []const u8) void {
    std.debug.print("JS says: {s}\n", .{msg});
}
