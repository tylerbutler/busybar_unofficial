//// Drawing elements on the displays and controlling brightness.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/assets
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

/// Text fonts available on the device. `Global` uses the device default.
pub type Font {
  Tiny
  Small
  Normal
  Condensed
  Bold
  Large
  ExtraLarge
  Global
}

fn font_to_string(font: Font) -> String {
  case font {
    Tiny -> "tiny"
    Small -> "small"
    Normal -> "normal"
    Condensed -> "condensed"
    Bold -> "bold"
    Large -> "large"
    ExtraLarge -> "extra_large"
    Global -> "global"
  }
}

/// Which physical display an element is drawn on.
pub type DisplayTarget {
  Front
  Back
}

fn target_to_string(target: DisplayTarget) -> String {
  case target {
    Front -> "front"
    Back -> "back"
  }
}

/// Anchor position of an element on the display.
pub type Align {
  TopLeft
  TopMid
  TopRight
  MidLeft
  Center
  MidRight
  BottomLeft
  BottomMid
  BottomRight
}

fn align_to_string(align: Align) -> String {
  case align {
    TopLeft -> "top_left"
    TopMid -> "top_mid"
    TopRight -> "top_right"
    MidLeft -> "mid_left"
    Center -> "center"
    MidRight -> "mid_right"
    BottomLeft -> "bottom_left"
    BottomMid -> "bottom_mid"
    BottomRight -> "bottom_right"
  }
}

/// Fill style for a `Rectangle` element.
pub type Fill {
  NoFill
  Solid
  GradientH
  GradientV
}

fn fill_to_string(fill: Fill) -> String {
  case fill {
    NoFill -> "none"
    Solid -> "solid"
    GradientH -> "gradient_h"
    GradientV -> "gradient_v"
  }
}

/// Whether a `Countdown` element counts down to, or up from, its timestamp.
pub type CountdownDirection {
  TimeLeft
  TimeSince
}

/// When a `Countdown` element shows the hours segment.
pub type ShowHours {
  WhenNonZero
  Always
}

/// An image/animation file: uploaded app assets or a stock file.
pub type AssetSource {
  AppAsset(path: String)
  StockAsset(path: String)
}

/// Properties shared by all element kinds.
pub type ElementBase {
  ElementBase(
    id: String,
    timeout: Option(Int),
    display_until: Option(String),
    x: Option(Int),
    y: Option(Int),
    display: Option(DisplayTarget),
    align: Option(Align),
  )
}

/// An ElementBase with only the id set.
pub fn element_base(id: String) -> ElementBase {
  ElementBase(
    id: id,
    timeout: None,
    display_until: None,
    x: None,
    y: None,
    display: None,
    align: None,
  )
}

/// One drawable element of a `DrawRequest`.
pub type Element {
  Text(
    base: ElementBase,
    text: String,
    font: Font,
    color: Option(String),
    width: Option(Int),
    scroll_rate: Option(Int),
    scroll_start_delay: Option(Int),
    scroll_repeat_delay: Option(Int),
  )
  Image(base: ElementBase, source: AssetSource, opacity: Option(Int))
  Animation(
    base: ElementBase,
    source: AssetSource,
    loop: Option(Bool),
    await_previous_end: Option(Bool),
    section: Option(String),
    opacity: Option(Int),
  )
  Countdown(
    base: ElementBase,
    timestamp: String,
    direction: CountdownDirection,
    show_hours: ShowHours,
    color: Option(String),
  )
  Rectangle(
    base: ElementBase,
    width: Int,
    height: Int,
    radius: Option(Int),
    fill: Option(Fill),
    fill_colors: Option(List(String)),
    border_width: Option(Int),
    border_color: Option(String),
  )
}

fn base_props(base: ElementBase, kind: String) -> List(#(String, Json)) {
  [#("id", json.string(base.id)), #("type", json.string(kind))]
  |> list.append(
    api.compact([
      #("timeout", option.map(base.timeout, json.int)),
      #("display_until", option.map(base.display_until, json.string)),
      #("x", option.map(base.x, json.int)),
      #("y", option.map(base.y, json.int)),
      #(
        "display",
        option.map(base.display, fn(t) { json.string(target_to_string(t)) }),
      ),
      #(
        "align",
        option.map(base.align, fn(a) { json.string(align_to_string(a)) }),
      ),
    ]),
  )
}

fn source_prop(source: AssetSource) -> #(String, Json) {
  case source {
    AppAsset(path) -> #("path", json.string(path))
    StockAsset(path) -> #("stock_path", json.string(path))
  }
}

/// Encode an `Element` as the JSON the device expects.
pub fn element_to_json(element: Element) -> Json {
  case element {
    Text(base, text, font, color, width, rate, start_delay, repeat_delay) ->
      json.object(
        list.flatten([
          base_props(base, "text"),
          [
            #("text", json.string(text)),
            #("font", json.string(font_to_string(font))),
          ],
          api.compact([
            #("color", option.map(color, json.string)),
            #("width", option.map(width, json.int)),
            #("scroll_rate", option.map(rate, json.int)),
            #("scroll_start_delay", option.map(start_delay, json.int)),
            #("scroll_repeat_delay", option.map(repeat_delay, json.int)),
          ]),
        ]),
      )
    Image(base, source, opacity) ->
      json.object(
        list.flatten([
          base_props(base, "image"),
          [source_prop(source)],
          api.compact([#("opacity", option.map(opacity, json.int))]),
        ]),
      )
    Animation(base, source, loop, await_previous_end, section, opacity) ->
      json.object(
        list.flatten([
          base_props(base, "animation"),
          [source_prop(source)],
          api.compact([
            #("loop", option.map(loop, json.bool)),
            #("await_previous_end", option.map(await_previous_end, json.bool)),
            #("section", option.map(section, json.string)),
            #("opacity", option.map(opacity, json.int)),
          ]),
        ]),
      )
    Countdown(base, timestamp, direction, show_hours, color) -> {
      let direction = case direction {
        TimeLeft -> "time_left"
        TimeSince -> "time_since"
      }
      let show_hours = case show_hours {
        WhenNonZero -> "when_non_zero"
        Always -> "always"
      }
      json.object(
        list.flatten([
          base_props(base, "countdown"),
          [
            #("timestamp", json.string(timestamp)),
            #("direction", json.string(direction)),
            #("show_hours", json.string(show_hours)),
          ],
          api.compact([#("color", option.map(color, json.string))]),
        ]),
      )
    }
    Rectangle(base, width, height, radius, fill, colors, b_width, b_color) ->
      json.object(
        list.flatten([
          base_props(base, "rectangle"),
          [#("width", json.int(width)), #("height", json.int(height))],
          api.compact([
            #("radius", option.map(radius, json.int)),
            #(
              "fill",
              option.map(fill, fn(f) { json.string(fill_to_string(f)) }),
            ),
            #(
              "fill_colors",
              option.map(colors, fn(c) { json.array(c, json.string) }),
            ),
            #("border_width", option.map(b_width, json.int)),
            #("border_color", option.map(b_color, json.string)),
          ]),
        ]),
      )
  }
}

/// A draw call: elements shown under one application name.
pub type DrawRequest {
  DrawRequest(
    application_name: String,
    priority: Option(Int),
    led_notification_color: Option(String),
    elements: List(Element),
  )
}

/// Build the `POST /display/draw` request without sending it.
pub fn draw_request(
  client: Client,
  draw: DrawRequest,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/display/draw"))
  let body =
    json.object(
      list.flatten([
        [#("application_name", json.string(draw.application_name))],
        api.compact([
          #("priority", option.map(draw.priority, json.int)),
          #(
            "led_notification_color",
            option.map(draw.led_notification_color, json.string),
          ),
        ]),
        [#("elements", json.array(draw.elements, element_to_json))],
      ]),
    )
  Ok(api.with_json_body(req, body))
}

/// Draw elements on the display.
pub fn draw(client: Client, draw: DrawRequest) -> Result(Nil, Error) {
  use req <- result.try(draw_request(client, draw))
  api.send_expect_success(req)
}

/// Build the `DELETE /display/draw` request without sending it.
pub fn clear_request(
  client: Client,
  application_name: Option(String),
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Delete, "/display/draw"))
  case application_name {
    Some(name) -> Ok(api.set_query(req, [#("application_name", name)]))
    None -> Ok(req)
  }
}

/// Clear drawn elements — all of them, or only one application's.
pub fn clear(
  client: Client,
  application_name: Option(String),
) -> Result(Nil, Error) {
  use req <- result.try(clear_request(client, application_name))
  api.send_expect_success(req)
}

/// Build the upload and draw requests for showing an image, without sending
/// either. The asset is uploaded under `draw.application_name`, so the name
/// the device files it under cannot drift from the name the elements
/// reference.
///
/// `file_name` must be a flat name like `"gleam.png"` — the upload endpoint
/// rejects `/` in it, even though `AppAsset` paths may contain one.
pub fn upload_and_draw_requests(
  client: Client,
  file_name: String,
  data: BitArray,
  draw: DrawRequest,
) -> Result(#(Request(BitArray), Request(String)), Error) {
  use upload <- result.try(assets.upload_request(
    client,
    draw.application_name,
    file_name,
    data,
  ))
  use drawing <- result.try(draw_request(client, draw))
  Ok(#(upload, drawing))
}

/// Upload an image asset, then draw the elements that reference it.
///
/// The draw API takes no inline image data, so showing custom artwork is
/// always these two calls. The image must already be scaled to the target
/// display: the front matrix is 72x16, the back screen 160x80.
///
/// A `draw.priority` of `None` defaults to 50 on the device, which draws over
/// the built-in apps but not over an active BUSY session — use `Some(90)` or
/// higher to preempt one.
pub fn upload_and_draw(
  client: Client,
  file_name: String,
  data: BitArray,
  draw: DrawRequest,
) -> Result(Nil, Error) {
  use #(upload, drawing) <- result.try(upload_and_draw_requests(
    client,
    file_name,
    data,
    draw,
  ))
  use _ <- result.try(api.send_bits_expect_success(upload))
  api.send_expect_success(drawing)
}

/// Display brightness: automatic or a fixed 0-100 level.
pub type Brightness {
  Auto
  Level(Int)
}

/// Decoder for the `GET /display/brightness` response body.
pub fn brightness_decoder() -> Decoder(Brightness) {
  use value <- decode.field("value", decode.string)
  case value {
    "auto" -> decode.success(Auto)
    _ ->
      case int.parse(value) {
        Ok(level) -> decode.success(Level(level))
        Error(Nil) -> decode.failure(Auto, "brightness")
      }
  }
}

fn brightness_to_string(brightness: Brightness) -> String {
  case brightness {
    Auto -> "auto"
    Level(level) -> int.to_string(level)
  }
}

/// Build the `GET /display/brightness` request without sending it.
pub fn get_brightness_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/display/brightness")
}

/// Get the current display brightness.
pub fn get_brightness(client: Client) -> Result(Brightness, Error) {
  use req <- result.try(get_brightness_request(client))
  api.send_json(req, brightness_decoder())
}

/// Build the `POST /display/brightness` request without sending it.
pub fn set_brightness_request(
  client: Client,
  brightness: Brightness,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(
    client,
    http.Post,
    "/display/brightness",
  ))
  Ok(api.set_query(req, [#("value", brightness_to_string(brightness))]))
}

/// Set the brightness of both displays.
pub fn set_brightness(
  client: Client,
  brightness: Brightness,
) -> Result(Nil, Error) {
  use req <- result.try(set_brightness_request(client, brightness))
  api.send_expect_success(req)
}
