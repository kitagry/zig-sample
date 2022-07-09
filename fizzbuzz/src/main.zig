const print = @import("std").debug.print;
const std = @import("std");

pub fn main() anyerror!void {
  var i: u32 = 1;
  const writer = std.io.getStdOut().writer();
  while (i < 100) : (i += 1) {
    try writeFizzBuzz(writer, i);
    try writer.print("\n", .{});
  }
}

fn writeFizzBuzz(writer: anytype, input: u32) !void {
  if (@mod(input, 3) == 0) try writer.print("{s}", .{"Fizz"});
  if (@mod(input, 5) == 0) try writer.print("{s}", .{"Buzz"});
  if (@mod(input, 3) != 0 and @mod(input, 5) != 0) try writer.print("{}", .{input});
}

test "writeFizzBuzz(1) returns 1" {
  var list = std.ArrayList(u8).init(std.testing.allocator);
  defer list.deinit();

  try writeFizzBuzz(list.writer(), 1);
  try std.testing.expect(std.mem.eql(u8, list.items, "1"));
}

test "writeFizzBuzz(3) returns Fizz" {
  var list = std.ArrayList(u8).init(std.testing.allocator);
  defer list.deinit();

  try writeFizzBuzz(list.writer(), 3);
  try std.testing.expect(std.mem.eql(u8, list.items, "Fizz"));
}

test "writeFizzBuzz(5) returns Buzz" {
  var list = std.ArrayList(u8).init(std.testing.allocator);
  defer list.deinit();

  try writeFizzBuzz(list.writer(), 5);
  try std.testing.expect(std.mem.eql(u8, list.items, "Buzz"));
}

test "writeFizzBuzz(15) returns FizzBuzz" {
  var list = std.ArrayList(u8).init(std.testing.allocator);
  defer list.deinit();

  try writeFizzBuzz(list.writer(), 15);
  try std.testing.expect(std.mem.eql(u8, list.items, "FizzBuzz"));
}
