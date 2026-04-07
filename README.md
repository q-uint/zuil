# ZUIL - Zig UI Library

A `zuil` (Dutch, noun) is primarily a vertical structure—a pillar, column, or post, used to support or adorn a building.

Pure Zig webview library. Calls the platform's native web engine directly through C interop with zero external dependencies.

## Platforms

| Platform | Engine | Status |
|----------|--------|--------|
| macOS | WebKit (WKWebView) | Working |
| Linux | WebKitGTK | Planned |
| Windows | WebView2 | Planned |

## Usage

```zig
const zuil = @import("zuil");

pub fn main() void {
    var wv: zuil.WebView = .{};
    wv.init(.{
        .title = "My App",
        .width = 1024,
        .height = 768,
        .html = "<h1>Hello from Zig</h1>",
        .callback = &onMessage,
    });
    wv.run();
}

fn onMessage(msg: []const u8) void {
    std.debug.print("JS: {s}\n", .{msg});
}
```

## API

| Method | Description |
|--------|-------------|
| `init(Options)` | Create window and webview |
| `run()` | Enter the event loop |
| `eval(js)` | Execute JavaScript |
| `setTitle(title)` | Change window title |
| `setHtml(html)` | Load HTML content |
| `navigate(url)` | Navigate to a URL |
| `terminate()` | Quit the application |

### JS Bridge

JavaScript can send messages to Zig via `zuil.postMessage(string)`, which is injected automatically. Messages arrive at the `callback` function passed in `Options`.

## Building

Requires Zig 0.15+ and Nix (for the dev shell).

```sh
nix develop
zig build run    # run the example
zig build test   # run tests
```

## License

MPL-2.0
