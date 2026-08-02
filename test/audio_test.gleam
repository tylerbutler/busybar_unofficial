import busybar_unofficial
import busybar_unofficial/audio
import gleam/http
import gleam/json
import gleam/option.{Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn play_request_app_asset_test() {
  let assert Ok(req) =
    audio.play_request(client(), "my_app", audio.AppAudio("data.snd"))
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/audio/play")
  req.body
  |> should.equal("{\"application_name\":\"my_app\",\"path\":\"data.snd\"}")
}

pub fn play_request_stock_asset_test() {
  let assert Ok(req) =
    audio.play_request(client(), "my_app", audio.StockAudio("shared/ding.snd"))
  req.body
  |> should.equal(
    "{\"application_name\":\"my_app\",\"stock_path\":\"shared/ding.snd\"}",
  )
}

pub fn stop_request_test() {
  let assert Ok(req) = audio.stop_request(client())
  req.method |> should.equal(http.Delete)
  req.path |> should.equal("/busybar/audio/play")
}

pub fn volume_decoder_int_test() {
  json.parse("{\"volume\":50}", audio.volume_decoder())
  |> should.equal(Ok(50.0))
}

pub fn volume_decoder_float_test() {
  json.parse("{\"volume\":42.5}", audio.volume_decoder())
  |> should.equal(Ok(42.5))
}

pub fn set_volume_request_test() {
  let assert Ok(req) = audio.set_volume_request(client(), 80, False)
  req.query |> should.equal(Some("volume=80"))
}

pub fn set_volume_request_silent_test() {
  let assert Ok(req) = audio.set_volume_request(client(), 80, True)
  req.query |> should.equal(Some("volume=80&silent=1"))
}
