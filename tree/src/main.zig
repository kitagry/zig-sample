const std = @import("std");
const path = @import("std").fs.path;
const Dir = @import("std").fs.Dir;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // this is binary name.
    _ = args.next();

    var w = std.io.getStdOut().writer();
    while (args.next()) |arg| {
      const pathname = try std.fs.path.resolve(allocator, &[_][]u8{@ptrCast([]u8, arg)});
      const dir = try std.fs.openDirAbsolute(pathname, .{ .iterate=true });

      var walker = try new_walker(dir, allocator);
      defer walker.deinit();

      var current_depth: u8 = 1;
      var current_prefix = std.ArrayList(u8).init(allocator);
      errdefer current_prefix.deinit();

      try w.print("{s}\n", .{arg});
      while (try walker.next()) |entry| {
        if (entry.depth < current_depth) {
          while (current_depth > entry.depth) : (current_depth -= 1) {
            if (current_prefix.items[current_prefix.items.len - 4] == ' ') {
              try current_prefix.resize(current_prefix.items.len - 4);
            } else {
              try current_prefix.resize(current_prefix.items.len - 6);
            }
          }
          current_depth = entry.depth;
        }

        const prefix = if ( entry.is_last ) "└── " else "├── ";
        try w.print("{s}{s}{s}\n", .{current_prefix.items, prefix, entry.basename});

        if (entry.kind == Dir.Entry.Kind.Directory) {
          try current_prefix.appendSlice(if (entry.is_last) "    " else "│   ");
          current_depth = entry.depth+1;
        }
      }
    }
}

/// Recursively iterates over a directory.
/// `self` must have been opened with `OpenDirOptions{.iterate = true}`.
/// Must call `Walker.deinit` when done.
/// The order of returned file system entries is undefined.
/// `self` will not be closed after walking it.
fn new_walker(self: std.fs.Dir, allocator: std.mem.Allocator) !Walker {
    var name_buffer = std.ArrayList(u8).init(allocator);
    errdefer name_buffer.deinit();

    var stack = std.ArrayList(Walker.StackItem).init(allocator);
    errdefer stack.deinit();

    try stack.append(Walker.StackItem{
        .iter = Peeker { .iter = self.iterate() },
        .dirname_len = 0,
        .depth = 0,
    });

    return Walker{
        .stack = stack,
        .name_buffer = name_buffer,
    };
}

const Peeker = struct {
  iter: std.fs.Dir.Iterator,
  peeked_item: ?std.fs.Dir.Entry = null,

  fn next(self: *Peeker) !?std.fs.Dir.Entry {
    const entry = self.peeked_item;
    if (entry != null) {
      self.peeked_item = null;
      return entry;
    }
    return self.iter.next();
  }

  fn peek(self: *Peeker) !?std.fs.Dir.Entry {
    if (self.peeked_item == null) {
      self.peeked_item = try self.iter.next();
    }
    return self.peeked_item;
  }
};

const Walker = struct {
  stack: std.ArrayList(StackItem),
  name_buffer: std.ArrayList(u8),

  pub const WalkerEntry = struct {
      /// The containing directory. This can be used to operate directly on `basename`
      /// rather than `path`, avoiding `error.NameTooLong` for deeply nested paths.
      /// The directory remains open until `next` or `deinit` is called.
      dir: Dir,
      basename: []const u8,
      depth: u8,
      kind: Dir.Entry.Kind,
      is_last: bool,
  };

  const StackItem = struct {
      iter: Peeker,
      dirname_len: usize,
      depth: u8,
  };

  /// After each call to this function, and on deinit(), the memory returned
  /// from this function becomes invalid. A copy must be made in order to keep
  /// a reference to the path.
  pub fn next(self: *Walker) !?WalkerEntry {
      while (self.stack.items.len != 0) {
          // `top` becomes invalid after appending to `self.stack`
          var top = &self.stack.items[self.stack.items.len - 1];
          var dirname_len = top.dirname_len;
          if (try top.iter.next()) |base| {
              self.name_buffer.shrinkRetainingCapacity(dirname_len);
              if (self.name_buffer.items.len != 0) {
                  try self.name_buffer.append(path.sep);
                  dirname_len += 1;
              }
              try self.name_buffer.appendSlice(base.name);
              const peeked_item = top.iter.peek() catch null;
              const is_last = peeked_item == null;
              const depth = top.depth + 1;
              if (base.kind == .Directory) {
                  var new_dir = top.iter.iter.dir.openDir(base.name, .{ .iterate = true }) catch |err| switch (err) {
                      error.NameTooLong => unreachable, // no path sep in base.name
                      else => |e| return e,
                  };
                  {
                      errdefer new_dir.close();
                      try self.stack.append(StackItem{
                          .iter = Peeker { .iter = new_dir.iterate() },
                          .dirname_len = self.name_buffer.items.len,
                          .depth = depth,
                      });
                      top = &self.stack.items[self.stack.items.len - 1];
                  }
              }
              return WalkerEntry{
                  .dir = top.iter.iter.dir,
                  .basename = self.name_buffer.items[dirname_len..],
                  .kind = base.kind,
                  .is_last = is_last,
                  .depth = depth,
              };
          } else {
              var item = self.stack.pop();
              if (self.stack.items.len != 0) {
                  item.iter.iter.dir.close();
              }
          }
      }
      return null;
  }

  pub fn deinit(self: *Walker) void {
      for (self.stack.items) |*item| {
          item.iter.iter.dir.close();
      }
      self.stack.deinit();
      self.name_buffer.deinit();
  }
};
