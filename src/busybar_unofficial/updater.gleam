//// Firmware updates: upload, check, install, and autoupdate settings.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/option.{type Option, None}
import gleam/result

/// Progress of an in-flight firmware download.
pub type DownloadProgress {
  DownloadProgress(
    speed_bytes_per_sec: Option(Int),
    received_bytes: Option(Int),
    total_bytes: Option(Int),
  )
}

/// Install progress. event/action/status are the spec's enum strings,
/// kept as String because they are informational and firmware-version
/// dependent.
pub type InstallStatus {
  InstallStatus(
    is_allowed: Option(Bool),
    event: Option(String),
    action: Option(String),
    status: Option(String),
    detail: Option(String),
    download: Option(DownloadProgress),
  )
}

/// Result of the last update-availability check.
pub type CheckStatus {
  CheckStatus(
    available_version: Option(String),
    event: Option(String),
    status: Option(String),
  )
}

/// Combined firmware update status: install progress and check result.
pub type UpdateStatus {
  UpdateStatus(install: Option(InstallStatus), check: Option(CheckStatus))
}

/// Automatic update configuration, with an optional daily time window
/// (`interval_start`/`interval_end`).
pub type AutoupdateSettings {
  AutoupdateSettings(
    is_enabled: Option(Bool),
    interval_start: Option(String),
    interval_end: Option(String),
  )
}

fn opt_string(name: String, next) {
  decode.optional_field(name, None, decode.optional(decode.string), next)
}

fn download_decoder() -> Decoder(DownloadProgress) {
  use speed_bytes_per_sec <- decode.optional_field(
    "speed_bytes_per_sec",
    None,
    decode.optional(decode.int),
  )
  use received_bytes <- decode.optional_field(
    "received_bytes",
    None,
    decode.optional(decode.int),
  )
  use total_bytes <- decode.optional_field(
    "total_bytes",
    None,
    decode.optional(decode.int),
  )
  decode.success(DownloadProgress(
    speed_bytes_per_sec:,
    received_bytes:,
    total_bytes:,
  ))
}

fn install_decoder() -> Decoder(InstallStatus) {
  use is_allowed <- decode.optional_field(
    "is_allowed",
    None,
    decode.optional(decode.bool),
  )
  use event <- opt_string("event")
  use action <- opt_string("action")
  use status <- opt_string("status")
  use detail <- opt_string("detail")
  use download <- decode.optional_field(
    "download",
    None,
    decode.optional(download_decoder()),
  )
  decode.success(InstallStatus(
    is_allowed:,
    event:,
    action:,
    status:,
    detail:,
    download:,
  ))
}

fn check_decoder() -> Decoder(CheckStatus) {
  use available_version <- opt_string("available_version")
  use event <- opt_string("event")
  use status <- opt_string("status")
  decode.success(CheckStatus(available_version:, event:, status:))
}

/// Decoder for the `GET /update/status` response body.
pub fn update_status_decoder() -> Decoder(UpdateStatus) {
  use install <- decode.optional_field(
    "install",
    None,
    decode.optional(install_decoder()),
  )
  use check <- decode.optional_field(
    "check",
    None,
    decode.optional(check_decoder()),
  )
  decode.success(UpdateStatus(install:, check:))
}

/// Decoder for the `GET /update/changelog` response body.
pub fn changelog_decoder() -> Decoder(String) {
  use changelog <- decode.field("changelog", decode.string)
  decode.success(changelog)
}

/// Decoder for the `GET /update/autoupdate` response body.
pub fn autoupdate_decoder() -> Decoder(AutoupdateSettings) {
  use is_enabled <- decode.optional_field(
    "is_enabled",
    None,
    decode.optional(decode.bool),
  )
  use interval_start <- opt_string("interval_start")
  use interval_end <- opt_string("interval_end")
  decode.success(AutoupdateSettings(is_enabled:, interval_start:, interval_end:))
}

/// Build the `POST /update` request without sending it.
pub fn upload_firmware_request(
  client: Client,
  data: BitArray,
) -> Result(Request(BitArray), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/update"))
  Ok(
    req
    |> request.set_header("content-type", "application/octet-stream")
    |> request.set_body(data),
  )
}

/// Upload a firmware archive directly.
pub fn upload_firmware(client: Client, data: BitArray) -> Result(Nil, Error) {
  use req <- result.try(upload_firmware_request(client, data))
  api.send_bits_expect_success(req)
}

/// Build the `POST /update/check` request without sending it.
pub fn check_for_update_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Post, "/update/check")
}

/// Start an update-availability check (poll `get_update_status` after).
pub fn check_for_update(client: Client) -> Result(Nil, Error) {
  use req <- result.try(check_for_update_request(client))
  api.send_expect_success(req)
}

/// Build the `GET /update/status` request without sending it.
pub fn get_update_status_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/update/status")
}

/// Get the firmware update status.
pub fn get_update_status(client: Client) -> Result(UpdateStatus, Error) {
  use req <- result.try(get_update_status_request(client))
  api.send_json(req, update_status_decoder())
}

/// Build the `GET /update/changelog` request without sending it.
pub fn get_changelog_request(
  client: Client,
  version: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Get, "/update/changelog"))
  Ok(api.set_query(req, [#("version", version)]))
}

/// Get the changelog for a firmware version.
pub fn get_changelog(client: Client, version: String) -> Result(String, Error) {
  use req <- result.try(get_changelog_request(client, version))
  api.send_json(req, changelog_decoder())
}

/// Build the `POST /update/install` request without sending it.
pub fn install_request(
  client: Client,
  version: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/update/install"))
  Ok(api.set_query(req, [#("version", version)]))
}

/// Download and install the given firmware version.
pub fn install(client: Client, version: String) -> Result(Nil, Error) {
  use req <- result.try(install_request(client, version))
  api.send_expect_success(req)
}

/// Build the `POST /update/abort_download` request without sending it.
pub fn abort_download_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Post, "/update/abort_download")
}

/// Abort an ongoing firmware download.
pub fn abort_download(client: Client) -> Result(Nil, Error) {
  use req <- result.try(abort_download_request(client))
  api.send_expect_success(req)
}

/// Build the `GET /update/autoupdate` request without sending it.
pub fn get_autoupdate_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/update/autoupdate")
}

/// Get the autoupdate settings.
pub fn get_autoupdate(client: Client) -> Result(AutoupdateSettings, Error) {
  use req <- result.try(get_autoupdate_request(client))
  api.send_json(req, autoupdate_decoder())
}

/// Build the `POST /update/autoupdate` request without sending it.
pub fn set_autoupdate_request(
  client: Client,
  settings: AutoupdateSettings,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/update/autoupdate"))
  let body =
    json.object(
      api.compact([
        #("is_enabled", option.map(settings.is_enabled, json.bool)),
        #("interval_start", option.map(settings.interval_start, json.string)),
        #("interval_end", option.map(settings.interval_end, json.string)),
      ]),
    )
  Ok(api.with_json_body(req, body))
}

/// Set the autoupdate settings.
pub fn set_autoupdate(
  client: Client,
  settings: AutoupdateSettings,
) -> Result(Nil, Error) {
  use req <- result.try(set_autoupdate_request(client, settings))
  api.send_expect_success(req)
}
