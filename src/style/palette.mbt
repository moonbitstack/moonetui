///|
/// The sixteen named colours as whatever paints the cells resolves them, in
/// terminal order: black, red, green, yellow, blue, magenta, cyan and white,
/// then their bright forms. A terminal lets its user choose these; a driver that
/// paints for itself, such as a canvas, takes them from here. An entry left out
/// resolves as the standard table does.
pub(all) struct Palette {
  named : Array[(Int32, Int32, Int32)]
}

///|
/// The standard table that `Colour::to_rgb` and the quantisers use, so a driver
/// paints what the rest of the library assumes unless it is told otherwise.
pub let palette : Palette = {
  named: Array::makei(16, i => Colour::Ansi(i).to_rgb().unwrap()),
}

///|
/// `colour` as red, green and blue under this palette, `None` for the default.
/// The first sixteen of the 256 are the named colours, as in a terminal.
pub fn Palette::rgb(self : Palette, colour : Colour) -> (Int32, Int32, Int32)? {
  match colour {
    Ansi(i) | Ansi256(i) if i >= 0 && i < 16 =>
      match self.named.get(i) {
        Some(rgb) => Some(rgb)
        None => colour.to_rgb()
      }
    _ => colour.to_rgb()
  }
}
