//// Bluetooth Low Energy control.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/option.{type Option, None}
import gleam/result

pub type BleState {
  Reset
  Initialization
  BleDisabled
  BleEnabled
  Connectable
  BleConnected
  BleInternalError
}

pub type BleStatus {
  BleStatus(state: BleState, address: Option(String))
}

pub fn status_decoder() -> Decoder(BleStatus) {
  use state <- decode.field(
    "status",
    api.enum_decoder("ble status", [
      #("reset", Reset),
      #("initialization", Initialization),
      #("disabled", BleDisabled),
      #("enabled", BleEnabled),
      #("connectable", Connectable),
      #("connected", BleConnected),
      #("internal error", BleInternalError),
    ]),
  )
  use address <- decode.optional_field(
    "address",
    None,
    decode.optional(decode.string),
  )
  decode.success(BleStatus(state:, address:))
}

pub fn enable_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Post, "/ble/enable")
}

pub fn enable(client: Client) -> Result(Nil, Error) {
  use req <- result.try(enable_request(client))
  api.send_expect_success(req)
}

pub fn disable_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Post, "/ble/disable")
}

pub fn disable(client: Client) -> Result(Nil, Error) {
  use req <- result.try(disable_request(client))
  api.send_expect_success(req)
}

pub fn unpair_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Delete, "/ble/pairing")
}

/// Remove all BLE pairings.
pub fn unpair(client: Client) -> Result(Nil, Error) {
  use req <- result.try(unpair_request(client))
  api.send_expect_success(req)
}

pub fn get_status_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/ble/status")
}

pub fn get_status(client: Client) -> Result(BleStatus, Error) {
  use req <- result.try(get_status_request(client))
  api.send_json(req, status_decoder())
}
