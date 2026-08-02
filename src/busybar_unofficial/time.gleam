//// Device clock and timezone.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/result

/// A timezone: IANA name, UTC offset, and abbreviation.
pub type Timezone {
  Timezone(name: String, offset: String, abbr: String)
}

/// Decoder for the `GET /time` response body.
pub fn timestamp_decoder() -> Decoder(String) {
  use timestamp <- decode.field("timestamp", decode.string)
  decode.success(timestamp)
}

/// Decoder for the `GET /time/timezone` response body.
pub fn timezone_decoder() -> Decoder(Timezone) {
  use name <- decode.field("name", decode.string)
  use offset <- decode.field("offset", decode.string)
  use abbr <- decode.field("abbr", decode.string)
  decode.success(Timezone(name:, offset:, abbr:))
}

/// Decoder for the `GET /time/tzlist` response body.
pub fn tzlist_decoder() -> Decoder(List(Timezone)) {
  use zones <- decode.optional_field(
    "list",
    [],
    decode.list(timezone_decoder()),
  )
  decode.success(zones)
}

/// Build the `GET /time` request without sending it.
pub fn get_time_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/time")
}

/// Current device time as an ISO 8601 string with timezone.
pub fn get_time(client: Client) -> Result(String, Error) {
  use req <- result.try(get_time_request(client))
  api.send_json(req, timestamp_decoder())
}

/// Build the `POST /time/timestamp` request without sending it.
pub fn set_timestamp_request(
  client: Client,
  timestamp: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/time/timestamp"))
  Ok(api.set_query(req, [#("timestamp", timestamp)]))
}

/// Set the device clock from an ISO 8601 timestamp.
pub fn set_timestamp(client: Client, timestamp: String) -> Result(Nil, Error) {
  use req <- result.try(set_timestamp_request(client, timestamp))
  api.send_expect_success(req)
}

/// Build the `GET /time/timezone` request without sending it.
pub fn get_timezone_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/time/timezone")
}

/// Get the device's current timezone.
pub fn get_timezone(client: Client) -> Result(Timezone, Error) {
  use req <- result.try(get_timezone_request(client))
  api.send_json(req, timezone_decoder())
}

/// Build the `POST /time/timezone` request without sending it.
pub fn set_timezone_request(
  client: Client,
  name: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/time/timezone"))
  Ok(api.set_query(req, [#("timezone", name)]))
}

/// Set the timezone by name (see `list_timezones`).
pub fn set_timezone(client: Client, name: String) -> Result(Nil, Error) {
  use req <- result.try(set_timezone_request(client, name))
  api.send_expect_success(req)
}

/// Build the `GET /time/tzlist` request without sending it.
pub fn list_timezones_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/time/tzlist")
}

/// List the timezones the device supports.
pub fn list_timezones(client: Client) -> Result(List(Timezone), Error) {
  use req <- result.try(list_timezones_request(client))
  api.send_json(req, tzlist_decoder())
}
