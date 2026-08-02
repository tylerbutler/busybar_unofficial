//// Audio playback and volume.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/int
import gleam/json
import gleam/result

/// An audio file: either uploaded app assets or a stock sound.
pub type AudioSource {
  AppAudio(path: String)
  StockAudio(path: String)
}

pub fn volume_decoder() -> Decoder(Float) {
  use volume <- decode.field(
    "volume",
    decode.one_of(decode.float, or: [decode.int |> decode.map(int.to_float)]),
  )
  decode.success(volume)
}

pub fn play_request(
  client: Client,
  application_name: String,
  source: AudioSource,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/audio/play"))
  let source_prop = case source {
    AppAudio(path) -> #("path", json.string(path))
    StockAudio(path) -> #("stock_path", json.string(path))
  }
  let body =
    json.object([
      #("application_name", json.string(application_name)),
      source_prop,
    ])
  Ok(api.with_json_body(req, body))
}

/// Play an audio file from the app's assets or the stock library.
pub fn play(
  client: Client,
  application_name: String,
  source: AudioSource,
) -> Result(Nil, Error) {
  use req <- result.try(play_request(client, application_name, source))
  api.send_expect_success(req)
}

pub fn stop_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Delete, "/audio/play")
}

pub fn stop(client: Client) -> Result(Nil, Error) {
  use req <- result.try(stop_request(client))
  api.send_expect_success(req)
}

pub fn get_volume_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/audio/volume")
}

pub fn get_volume(client: Client) -> Result(Float, Error) {
  use req <- result.try(get_volume_request(client))
  api.send_json(req, volume_decoder())
}

pub fn set_volume_request(
  client: Client,
  volume: Int,
  silent: Bool,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/audio/volume"))
  let params = case silent {
    True -> [#("volume", int.to_string(volume)), #("silent", "1")]
    False -> [#("volume", int.to_string(volume))]
  }
  Ok(api.set_query(req, params))
}

/// Set volume (0-100). When `silent` is True the change chime is suppressed.
pub fn set_volume(
  client: Client,
  volume: Int,
  silent: Bool,
) -> Result(Nil, Error) {
  use req <- result.try(set_volume_request(client, volume, silent))
  api.send_expect_success(req)
}
