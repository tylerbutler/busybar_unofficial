//// Linked BUSY Cloud account info.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/option.{type Option, None}
import gleam/result

/// Linked cloud account details. The optional fields are populated only
/// when an account is linked.
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

/// Client TLS certificate type used for the MQTT backend connection.
pub type CertType {
  DefaultCert
  CustomCert
  NoCert
}

/// MQTT backend configuration.
pub type AccountBackend {
  AccountBackend(
    server_url: String,
    client_cert_type: CertType,
    ignore_server_cert: Bool,
  )
}

/// Decoder for the `GET /account/info` response body.
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

/// Decoder for the `GET /account/status` response body.
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

/// Decoder for the `GET /account/backend` response body.
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

/// Build the `GET /account/info` request without sending it.
pub fn get_info_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/account/info")
}

/// Get the linked BUSY Cloud account info.
pub fn get_info(client: Client) -> Result(AccountInfo, Error) {
  use req <- result.try(get_info_request(client))
  api.send_json(req, info_decoder())
}

/// Build the `GET /account/status` request without sending it.
pub fn get_status_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/account/status")
}

/// Get the MQTT connection status to the cloud backend.
pub fn get_status(client: Client) -> Result(ConnectionStatus, Error) {
  use req <- result.try(get_status_request(client))
  api.send_json(req, status_decoder())
}

/// Build the `GET /account/backend` request without sending it.
pub fn get_backend_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/account/backend")
}

/// Get the MQTT backend configuration.
pub fn get_backend(client: Client) -> Result(AccountBackend, Error) {
  use req <- result.try(get_backend_request(client))
  api.send_json(req, backend_decoder())
}
