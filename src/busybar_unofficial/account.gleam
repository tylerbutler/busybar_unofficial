//// Linked BUSY Cloud account info.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/option.{type Option, None}
import gleam/result

pub type AccountInfo {
  AccountInfo(
    linked: Bool,
    id: Option(String),
    email: Option(String),
    user_id: Option(String),
  )
}

/// MQTT connection status to the cloud backend.
pub type ConnectionStatus {
  ConnectionError
  Disconnected
  Connected
}

pub type CertType {
  DefaultCert
  CustomCert
  NoCert
}

pub type AccountBackend {
  AccountBackend(
    server_url: String,
    client_cert_type: CertType,
    ignore_server_cert: Bool,
  )
}

pub fn info_decoder() -> Decoder(AccountInfo) {
  use linked <- decode.optional_field("linked", False, decode.bool)
  use id <- decode.optional_field("id", None, decode.optional(decode.string))
  use email <- decode.optional_field(
    "email",
    None,
    decode.optional(decode.string),
  )
  use user_id <- decode.optional_field(
    "user_id",
    None,
    decode.optional(decode.string),
  )
  decode.success(AccountInfo(linked:, id:, email:, user_id:))
}

pub fn status_decoder() -> Decoder(ConnectionStatus) {
  use status <- decode.field(
    "status",
    api.enum_decoder("account status", [
      #("error", ConnectionError),
      #("disconnected", Disconnected),
      #("connected", Connected),
    ]),
  )
  decode.success(status)
}

pub fn backend_decoder() -> Decoder(AccountBackend) {
  use server_url <- decode.field("server_url", decode.string)
  use client_cert_type <- decode.field(
    "client_cert_type",
    api.enum_decoder("cert type", [
      #("default", DefaultCert),
      #("custom", CustomCert),
      #("none", NoCert),
    ]),
  )
  use ignore_server_cert <- decode.field("ignore_server_cert", decode.bool)
  decode.success(AccountBackend(
    server_url:,
    client_cert_type:,
    ignore_server_cert:,
  ))
}

pub fn get_info_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/account/info")
}

pub fn get_info(client: Client) -> Result(AccountInfo, Error) {
  use req <- result.try(get_info_request(client))
  api.send_json(req, info_decoder())
}

pub fn get_status_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/account/status")
}

pub fn get_status(client: Client) -> Result(ConnectionStatus, Error) {
  use req <- result.try(get_status_request(client))
  api.send_json(req, status_decoder())
}

pub fn get_backend_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/account/backend")
}

pub fn get_backend(client: Client) -> Result(AccountBackend, Error) {
  use req <- result.try(get_backend_request(client))
  api.send_json(req, backend_decoder())
}
