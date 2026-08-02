//// Device settings: input keys, HTTP access mode, name, transport.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result

/// Physical/virtual keys accepted by POST /input.
pub type InputKey {
  KeyUp
  KeyDown
  KeyOk
  KeyBack
  KeyStart
  KeyBusy
  KeyCustom
  KeyOff
  KeyApps
  KeySettings
}

fn key_to_string(key: InputKey) -> String {
  case key {
    KeyUp -> "up"
    KeyDown -> "down"
    KeyOk -> "ok"
    KeyBack -> "back"
    KeyStart -> "start"
    KeyBusy -> "busy"
    KeyCustom -> "custom"
    KeyOff -> "off"
    KeyApps -> "apps"
    KeySettings -> "settings"
  }
}

/// HTTP API access mode of the device.
pub type AccessMode {
  AccessDisabled
  AccessEnabled
  AccessKey
}

fn mode_to_string(mode: AccessMode) -> String {
  case mode {
    AccessDisabled -> "disabled"
    AccessEnabled -> "enabled"
    AccessKey -> "key"
  }
}

pub type AccessInfo {
  AccessInfo(mode: AccessMode, key_valid: Option(Bool))
}

/// How the device is currently reachable.
pub type NetworkInterface {
  UsbInterface
  WifiInterface
}

pub fn access_decoder() -> Decoder(AccessInfo) {
  use mode <- decode.field(
    "mode",
    api.enum_decoder("access mode", [
      #("disabled", AccessDisabled),
      #("enabled", AccessEnabled),
      #("key", AccessKey),
    ]),
  )
  use key_valid <- decode.optional_field(
    "key_valid",
    None,
    decode.optional(decode.bool),
  )
  decode.success(AccessInfo(mode:, key_valid:))
}

pub fn name_decoder() -> Decoder(String) {
  use name <- decode.field("name", decode.string)
  decode.success(name)
}

pub fn transport_decoder() -> Decoder(NetworkInterface) {
  use type_ <- decode.field(
    "type",
    api.enum_decoder("network interface", [
      #("usb", UsbInterface),
      #("wifi", WifiInterface),
    ]),
  )
  decode.success(type_)
}

pub fn press_key_request(
  client: Client,
  key: InputKey,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/input"))
  Ok(request.set_query(req, [#("key", key_to_string(key))]))
}

/// Simulate pressing a device key.
pub fn press_key(client: Client, key: InputKey) -> Result(Nil, Error) {
  use req <- result.try(press_key_request(client, key))
  api.send_expect_success(req)
}

pub fn get_access_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/access")
}

pub fn get_access(client: Client) -> Result(AccessInfo, Error) {
  use req <- result.try(get_access_request(client))
  api.send_json(req, access_decoder())
}

pub fn set_access_request(
  client: Client,
  mode: AccessMode,
  key: Option(String),
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/access"))
  let params = case key {
    Some(key) -> [#("mode", mode_to_string(mode)), #("key", key)]
    None -> [#("mode", mode_to_string(mode))]
  }
  Ok(request.set_query(req, params))
}

/// Set the HTTP access mode. `key` (4-10 digits) is required for AccessKey.
pub fn set_access(
  client: Client,
  mode: AccessMode,
  key: Option(String),
) -> Result(Nil, Error) {
  use req <- result.try(set_access_request(client, mode, key))
  api.send_expect_success(req)
}

pub fn get_name_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/name")
}

pub fn get_name(client: Client) -> Result(String, Error) {
  use req <- result.try(get_name_request(client))
  api.send_json(req, name_decoder())
}

pub fn set_name_request(
  client: Client,
  name: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/name"))
  Ok(api.with_json_body(req, json.object([#("name", json.string(name))])))
}

pub fn set_name(client: Client, name: String) -> Result(Nil, Error) {
  use req <- result.try(set_name_request(client, name))
  api.send_expect_success(req)
}

pub fn get_transport_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/transport")
}

pub fn get_transport(client: Client) -> Result(NetworkInterface, Error) {
  use req <- result.try(get_transport_request(client))
  api.send_json(req, transport_decoder())
}
