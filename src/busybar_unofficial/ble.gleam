//// Bluetooth Low Energy control.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/option.{type Option, None}
import gleam/result

/// Lifecycle state of the BLE module.
pub type BleState {
  Reset
  Initialization
  BleDisabled
  BleEnabled
  Connectable
  BleConnected
  BleInternalError
}

/// Current BLE state and, when available, the device's BLE address.
pub type BleStatus {
  BleStatus(state: BleState, address: Option(String))
}

/// Decoder for the `GET /ble/status` response body.
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

/// Build the `POST /ble/enable` request without sending it.
pub fn enable_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Post, "/ble/enable")
}

/// Enable the BLE module and start advertising.
pub fn enable(client: Client) -> Result(Nil, Error) {
  use req <- result.try(enable_request(client))
  api.send_expect_success(req)
}

/// Build the `POST /ble/disable` request without sending it.
pub fn disable_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Post, "/ble/disable")
}

/// Disable the BLE module and stop advertising.
pub fn disable(client: Client) -> Result(Nil, Error) {
  use req <- result.try(disable_request(client))
  api.send_expect_success(req)
}

/// Build the `DELETE /ble/pairing` request without sending it.
pub fn unpair_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Delete, "/ble/pairing")
}

/// Remove all BLE pairings.
pub fn unpair(client: Client) -> Result(Nil, Error) {
  use req <- result.try(unpair_request(client))
  api.send_expect_success(req)
}

/// Build the `GET /ble/status` request without sending it.
pub fn get_status_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/ble/status")
}

/// Get the current BLE status.
pub fn get_status(client: Client) -> Result(BleStatus, Error) {
  use req <- result.try(get_status_request(client))
  api.send_json(req, status_decoder())
}
