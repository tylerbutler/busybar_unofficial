//// Wi-Fi connection status.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/option.{type Option, None}
import gleam/result

/// Wi-Fi connection state.
pub type WifiState {
  StateUnknown
  StateDisconnected
  StateConnected
  StateConnecting
  StateDisconnecting
  StateReconnecting
}

/// IP configuration of the Wi-Fi interface.
pub type IpConfig {
  IpConfig(
    ip_method: Option(String),
    ip_type: Option(String),
    address: Option(String),
  )
}

/// Wi-Fi connection status. Fields beyond `state` are present only when
/// the device reports them.
pub type WifiStatus {
  WifiStatus(
    state: WifiState,
    ssid: Option(String),
    bssid: Option(String),
    channel: Option(Int),
    rssi: Option(Int),
    /// Kept as String deliberately: the spec's WifiSecurityMethod enum
    /// values (WPA3, WPA2/WPA3, ...) are informational and
    /// firmware-dependent.
    security: Option(String),
    ip_config: Option(IpConfig),
  )
}

fn ip_config_decoder() -> Decoder(IpConfig) {
  use ip_method <- decode.optional_field(
    "ip_method",
    None,
    decode.optional(decode.string),
  )
  use ip_type <- decode.optional_field(
    "ip_type",
    None,
    decode.optional(decode.string),
  )
  use address <- decode.optional_field(
    "address",
    None,
    decode.optional(decode.string),
  )
  decode.success(IpConfig(ip_method:, ip_type:, address:))
}

/// Decoder for the `GET /wifi/status` response body.
pub fn status_decoder() -> Decoder(WifiStatus) {
  use state <- decode.field(
    "state",
    api.enum_decoder("wifi state", [
      #("unknown", StateUnknown),
      #("disconnected", StateDisconnected),
      #("connected", StateConnected),
      #("connecting", StateConnecting),
      #("disconnecting", StateDisconnecting),
      #("reconnecting", StateReconnecting),
    ]),
  )
  use ssid <- decode.optional_field(
    "ssid",
    None,
    decode.optional(decode.string),
  )
  use bssid <- decode.optional_field(
    "bssid",
    None,
    decode.optional(decode.string),
  )
  use channel <- decode.optional_field(
    "channel",
    None,
    decode.optional(decode.int),
  )
  use rssi <- decode.optional_field("rssi", None, decode.optional(decode.int))
  use security <- decode.optional_field(
    "security",
    None,
    decode.optional(decode.string),
  )
  use ip_config <- decode.optional_field(
    "ip_config",
    None,
    decode.optional(ip_config_decoder()),
  )
  decode.success(WifiStatus(
    state:,
    ssid:,
    bssid:,
    channel:,
    rssi:,
    security:,
    ip_config:,
  ))
}

/// Build the `GET /wifi/status` request without sending it.
pub fn get_status_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/wifi/status")
}

/// Get the Wi-Fi connection status.
pub fn get_status(client: Client) -> Result(WifiStatus, Error) {
  use req <- result.try(get_status_request(client))
  api.send_json(req, status_decoder())
}
