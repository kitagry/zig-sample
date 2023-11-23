const std = @import("std");

const uri = std.Uri.parse("https://google.com") catch @compileError("invalid uri");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var headers: std.http.Headers = .{ .allocator = allocator };
    defer headers.deinit();

    var req = try client.request(std.http.Method.GET, uri, headers, .{});
    defer req.deinit();

    try req.start();
    try req.wait();

    var buf = std.io.bufferedReader(req.reader());
    var r = buf.reader();

    var msg_buf: [4096]u8 = undefined;
    var msg = try r.readUntilDelimiterOrEof(&msg_buf, '\n');
    if (msg) |m| {
        try std.io.getStdOut().writer().print("{s}\n", .{m});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
