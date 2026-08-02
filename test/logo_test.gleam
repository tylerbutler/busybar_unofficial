//// The committed Gleam logo assets in `priv/`. The device does not resize
//// images, so wrong dimensions here mean a wrong picture on the bar — assert
//// them straight out of the PNG header.

import gleeunit/should
import simplifile

const png_magic = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>

/// Read a PNG's IHDR width and height. The header is fixed-layout: the 8-byte
/// magic, then a 4-byte chunk length and the `IHDR` tag, then width and
/// height. Fails on anything that is not a PNG.
fn png_size(bits: BitArray) -> Result(#(Int, Int), Nil) {
  case bits {
    <<
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      _length:size(32),
      "IHDR":utf8,
      width:size(32),
      height:size(32),
      _rest:bits,
    >> -> Ok(#(width, height))
    _ -> Error(Nil)
  }
}

fn read_logo(name: String) -> BitArray {
  let assert Ok(bits) = simplifile.read_bits("priv/" <> name)
  bits
}

pub fn front_logo_is_a_png_test() {
  let assert <<magic:bytes-size(8), _rest:bits>> =
    read_logo("gleam_logo_72x16.png")
  magic |> should.equal(png_magic)
}

pub fn front_logo_fits_the_led_matrix_test() {
  read_logo("gleam_logo_72x16.png")
  |> png_size
  |> should.equal(Ok(#(72, 16)))
}

pub fn back_logo_fits_the_back_screen_test() {
  read_logo("gleam_logo_160x80.png")
  |> png_size
  |> should.equal(Ok(#(160, 80)))
}
