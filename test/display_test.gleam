import busybar_unofficial
import busybar_unofficial/display.{
  Auto, Bold, DrawRequest, Level, StockAsset, Text,
}
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn text_element_minimal_json_test() {
  let element =
    Text(
      base: display.element_base("greeting"),
      text: "hello",
      font: Bold,
      color: None,
      width: None,
      scroll_rate: None,
      scroll_start_delay: None,
      scroll_repeat_delay: None,
    )
  display.element_to_json(element)
  |> json.to_string
  |> should.equal(
    "{\"id\":\"greeting\",\"type\":\"text\",\"text\":\"hello\",\"font\":\"bold\"}",
  )
}

pub fn text_element_with_base_options_test() {
  let base =
    display.ElementBase(
      id: "e1",
      timeout: Some(30),
      display_until: None,
      x: Some(4),
      y: Some(2),
      display: Some(display.Back),
      align: Some(display.Center),
    )
  let element =
    Text(
      base: base,
      text: "hi",
      font: display.Tiny,
      color: Some("#FF0000FF"),
      width: None,
      scroll_rate: None,
      scroll_start_delay: None,
      scroll_repeat_delay: None,
    )
  display.element_to_json(element)
  |> json.to_string
  |> should.equal(
    "{\"id\":\"e1\",\"type\":\"text\",\"timeout\":30,\"x\":4,\"y\":2,"
    <> "\"display\":\"back\",\"align\":\"center\",\"text\":\"hi\","
    <> "\"font\":\"tiny\",\"color\":\"#FF0000FF\"}",
  )
}

pub fn image_element_json_test() {
  let element =
    display.Image(
      base: display.element_base("logo"),
      source: display.AppAsset("img/logo.px"),
      opacity: Some(50),
    )
  display.element_to_json(element)
  |> json.to_string
  |> should.equal(
    "{\"id\":\"logo\",\"type\":\"image\",\"path\":\"img/logo.px\",\"opacity\":50}",
  )
}

pub fn animation_element_stock_json_test() {
  let element =
    display.Animation(
      base: display.element_base("spin"),
      source: StockAsset("shared/spinner.px"),
      loop: Some(True),
      await_previous_end: None,
      section: None,
      opacity: None,
    )
  display.element_to_json(element)
  |> json.to_string
  |> should.equal(
    "{\"id\":\"spin\",\"type\":\"animation\","
    <> "\"stock_path\":\"shared/spinner.px\",\"loop\":true}",
  )
}

pub fn countdown_element_json_test() {
  let element =
    display.Countdown(
      base: display.element_base("cd"),
      timestamp: "1767225600",
      direction: display.TimeLeft,
      show_hours: display.Always,
      color: None,
    )
  display.element_to_json(element)
  |> json.to_string
  |> should.equal(
    "{\"id\":\"cd\",\"type\":\"countdown\",\"timestamp\":\"1767225600\","
    <> "\"direction\":\"time_left\",\"show_hours\":\"always\"}",
  )
}

pub fn rectangle_element_json_test() {
  let element =
    display.Rectangle(
      base: display.element_base("box"),
      width: 10,
      height: 5,
      radius: Some(2),
      fill: Some(display.Solid),
      fill_colors: Some(["#FFFFFFFF"]),
      border_width: None,
      border_color: None,
    )
  display.element_to_json(element)
  |> json.to_string
  |> should.equal(
    "{\"id\":\"box\",\"type\":\"rectangle\",\"width\":10,\"height\":5,"
    <> "\"radius\":2,\"fill\":\"solid\",\"fill_colors\":[\"#FFFFFFFF\"]}",
  )
}

pub fn draw_request_test() {
  let assert Ok(req) =
    display.draw_request(
      client(),
      DrawRequest(
        application_name: "my_app",
        priority: Some(10),
        led_notification_color: None,
        elements: [],
      ),
    )
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/display/draw")
  req.body
  |> should.equal(
    "{\"application_name\":\"my_app\",\"priority\":10,\"elements\":[]}",
  )
}

pub fn clear_request_scoped_test() {
  let assert Ok(req) = display.clear_request(client(), Some("my_app"))
  req.method |> should.equal(http.Delete)
  req.query |> should.equal(Some("application_name=my_app"))
}

pub fn upload_and_draw_requests_test() {
  let draw =
    DrawRequest(
      application_name: "gleam_logo",
      priority: Some(90),
      led_notification_color: None,
      elements: [
        display.Image(
          base: display.element_base("lucy"),
          source: display.AppAsset("gleam.png"),
          opacity: None,
        ),
      ],
    )
  let assert Ok(#(upload, drawing)) =
    display.upload_and_draw_requests(client(), "gleam.png", <<137, 80>>, draw)

  upload.method |> should.equal(http.Post)
  upload.path |> should.equal("/busybar/assets/upload")
  upload.query
  |> should.equal(Some("application_name=gleam_logo&file=gleam.png"))
  upload.body |> should.equal(<<137, 80>>)
  request.get_header(upload, "content-type")
  |> should.equal(Ok("application/octet-stream"))

  drawing.method |> should.equal(http.Post)
  drawing.path |> should.equal("/busybar/display/draw")
  drawing.body
  |> should.equal(
    "{\"application_name\":\"gleam_logo\",\"priority\":90,\"elements\":"
    <> "[{\"id\":\"lucy\",\"type\":\"image\",\"path\":\"gleam.png\"}]}",
  )
}

pub fn brightness_decoder_auto_test() {
  json.parse("{\"value\":\"auto\"}", display.brightness_decoder())
  |> should.equal(Ok(Auto))
}

pub fn brightness_decoder_level_test() {
  json.parse("{\"value\":\"70\"}", display.brightness_decoder())
  |> should.equal(Ok(Level(70)))
}

pub fn set_brightness_request_test() {
  let assert Ok(req) = display.set_brightness_request(client(), Level(55))
  req.query |> should.equal(Some("value=55"))
}

pub fn set_brightness_auto_request_test() {
  let assert Ok(req) = display.set_brightness_request(client(), Auto)
  req.query |> should.equal(Some("value=auto"))
}
