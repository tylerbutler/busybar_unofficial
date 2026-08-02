//// Matter smart home pairing and the emulated busy switch.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/option.{type Option, None}
import gleam/result

pub type PairingResult {
  NeverStarted
  Started
  CompletedSuccessfully
  Failed
}

pub type PairingAttempt {
  PairingAttempt(value: PairingResult, timestamp: Option(Int))
}

pub type PairingInfo {
  PairingInfo(fabric_count: Int, latest_pairing_status: Option(PairingAttempt))
}

/// Codes for commissioning the device into a Matter smart home.
pub type PairingPayload {
  PairingPayload(
    available_until: Option(String),
    qr_code: Option(String),
    manual_code: Option(String),
  )
}

/// Emulated switch state on device startup.
pub type SwitchStartup {
  StartupOff
  StartupOn
  StartupToggle
  StartupLast
}

fn startup_to_string(startup: SwitchStartup) -> String {
  case startup {
    StartupOff -> "off"
    StartupOn -> "on"
    StartupToggle -> "toggle"
    StartupLast -> "last"
  }
}

fn pairing_attempt_decoder() -> Decoder(PairingAttempt) {
  use value <- decode.field(
    "value",
    api.enum_decoder("pairing status", [
      #("never_started", NeverStarted),
      #("started", Started),
      #("completed_successfully", CompletedSuccessfully),
      #("failed", Failed),
    ]),
  )
  use timestamp <- decode.optional_field(
    "timestamp",
    None,
    decode.optional(decode.int),
  )
  decode.success(PairingAttempt(value:, timestamp:))
}

pub fn pairing_info_decoder() -> Decoder(PairingInfo) {
  use fabric_count <- decode.optional_field("fabric_count", 0, decode.int)
  use latest_pairing_status <- decode.optional_field(
    "latest_pairing_status",
    None,
    decode.optional(pairing_attempt_decoder()),
  )
  decode.success(PairingInfo(fabric_count:, latest_pairing_status:))
}

pub fn pairing_payload_decoder() -> Decoder(PairingPayload) {
  use available_until <- decode.optional_field(
    "available_until",
    None,
    decode.optional(decode.string),
  )
  use qr_code <- decode.optional_field(
    "qr_code",
    None,
    decode.optional(decode.string),
  )
  use manual_code <- decode.optional_field(
    "manual_code",
    None,
    decode.optional(decode.string),
  )
  decode.success(PairingPayload(available_until:, qr_code:, manual_code:))
}

pub fn switch_decoder() -> Decoder(Bool) {
  use state <- decode.field("state", decode.bool)
  decode.success(state)
}

pub fn get_pairing_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/smart_home/pairing")
}

pub fn get_pairing(client: Client) -> Result(PairingInfo, Error) {
  use req <- result.try(get_pairing_request(client))
  api.send_json(req, pairing_info_decoder())
}

pub fn start_pairing_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Post, "/smart_home/pairing")
}

/// Open the commissioning window; returns QR and manual pairing codes.
pub fn start_pairing(client: Client) -> Result(PairingPayload, Error) {
  use req <- result.try(start_pairing_request(client))
  api.send_json(req, pairing_payload_decoder())
}

pub fn unpair_all_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Delete, "/smart_home/pairing")
}

/// Remove the device from all Matter fabrics.
pub fn unpair_all(client: Client) -> Result(Nil, Error) {
  use req <- result.try(unpair_all_request(client))
  api.send_expect_success(req)
}

pub fn get_switch_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/smart_home/switch")
}

/// Current state of the emulated switch.
pub fn get_switch(client: Client) -> Result(Bool, Error) {
  use req <- result.try(get_switch_request(client))
  api.send_json(req, switch_decoder())
}

pub fn set_switch_request(
  client: Client,
  state: Option(Bool),
  startup: Option(SwitchStartup),
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/smart_home/switch"))
  let body =
    json.object(
      api.compact([
        #("state", option.map(state, json.bool)),
        #(
          "startup",
          option.map(startup, fn(s) { json.string(startup_to_string(s)) }),
        ),
      ]),
    )
  Ok(api.with_json_body(req, body))
}

/// Set the emulated switch state and/or its startup behaviour.
pub fn set_switch(
  client: Client,
  state: Option(Bool),
  startup: Option(SwitchStartup),
) -> Result(Nil, Error) {
  use req <- result.try(set_switch_request(client, state, startup))
  api.send_expect_success(req)
}
