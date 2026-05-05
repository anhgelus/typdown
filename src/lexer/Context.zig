current_line: usize = 1,
new_block: bool = true,
last_valid: usize = 0,

const Self = @This();

pub fn newLine(self: *Self) void {
    self.current_line += 1;
}
