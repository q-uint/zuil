const builtin = @import("builtin");

pub const WebView = switch (builtin.os.tag) {
    .macos => @import("macos.zig").WebView,
    else => @compileError("unsupported platform"),
};

test {
    _ = @import("macos.zig");
}
