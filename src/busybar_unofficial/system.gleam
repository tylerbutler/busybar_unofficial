//// Device status, version, screen capture, and log dumps.

import busybar_unofficial.{type Client, type Error, UnexpectedResponse}
import busybar_unofficial/internal/api
import gleam/bit_array
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/option.{type Option, None, Some}
import gleam/result

/// Firmware security state reported by the device.
pub type FirmwareSecurity {
  Secure
  Insecure
  OtherSecurity
  UnknownSecurity
}

/// Battery charging state.
pub type PowerState {
  Discharging
  Charging
  Charged
}

/// Which physical display to capture with `get_screen`.
pub type ScreenId {
  FrontScreen
  BackScreen
}

/// Hardware identity: serial number, MAC addresses, and OTP info.
pub type StatusDevice {
  StatusDevice(
    serial_number: String,
    usb_mac: String,
    wifi_mac: Option(String),
    ble_mac: Option(String),
    otp_valid: Bool,
    otp_model: Option(String),
    otp_timestamp: Option(Int),
    firmware_security: FirmwareSecurity,
  )
}

/// Installed firmware details.
pub type StatusFirmware {
  StatusFirmware(
    version: String,
    target: Int,
    branch: String,
    build_date: String,
    commit_hash: String,
    intercom_version: String,
    nwp_version: Option(String),
    matter_version: Option(String),
  )
}

/// System runtime information.
pub type StatusSystem {
  StatusSystem(
    api_semver: String,
    uptime: String,
    boot_time: Int,
    auto_update_enabled: Bool,
  )
}

/// Battery and power measurements.
pub type StatusPower {
  StatusPower(
    state: PowerState,
    battery_charge: Int,
    battery_voltage: Int,
    battery_current: Int,
    usb_voltage: Int,
  )
}

/// Combined device status. Sections the device omitted are `None`.
pub type Status {
  Status(
    device: Option(StatusDevice),
    firmware: Option(StatusFirmware),
    system: Option(StatusSystem),
    power: Option(StatusPower),
  )
}

/// Decoder for the `GET /status/device` response body.
pub fn device_decoder() -> Decoder(StatusDevice) {
  use serial_number <- decode.field("serial_number", decode.string)
  use usb_mac <- decode.field("usb_mac", decode.string)
  use wifi_mac <- decode.optional_field(
    "wifi_mac",
    None,
    decode.optional(decode.string),
  )
  use ble_mac <- decode.optional_field(
    "ble_mac",
    None,
    decode.optional(decode.string),
  )
  use otp_valid <- decode.field("otp_valid", decode.bool)
  use otp_model <- decode.optional_field(
    "otp_model",
    None,
    decode.optional(decode.string),
  )
  use otp_timestamp <- decode.optional_field(
    "otp_timestamp",
    None,
    decode.optional(decode.int),
  )
  use firmware_security <- decode.field(
    "firmware_security",
    api.enum_decoder("firmware security", [
      #("secure", Secure),
      #("insecure", Insecure),
      #("other", OtherSecurity),
      #("unknown", UnknownSecurity),
    ]),
  )
  decode.success(StatusDevice(
    serial_number:,
    usb_mac:,
    wifi_mac:,
    ble_mac:,
    otp_valid:,
    otp_model:,
    otp_timestamp:,
    firmware_security:,
  ))
}

/// Decoder for the `GET /status/firmware` response body.
pub fn firmware_decoder() -> Decoder(StatusFirmware) {
  use version <- decode.field("version", decode.string)
  use target <- decode.field("target", decode.int)
  use branch <- decode.field("branch", decode.string)
  use build_date <- decode.field("build_date", decode.string)
  use commit_hash <- decode.field("commit_hash", decode.string)
  use intercom_version <- decode.field("intercom_version", decode.string)
  use nwp_version <- decode.optional_field(
    "nwp_version",
    None,
    decode.optional(decode.string),
  )
  use matter_version <- decode.optional_field(
    "matter_version",
    None,
    decode.optional(decode.string),
  )
  decode.success(StatusFirmware(
    version:,
    target:,
    branch:,
    build_date:,
    commit_hash:,
    intercom_version:,
    nwp_version:,
    matter_version:,
  ))
}

/// Decoder for the `GET /status/system` response body.
pub fn system_decoder() -> Decoder(StatusSystem) {
  use api_semver <- decode.field("api_semver", decode.string)
  use uptime <- decode.field("uptime", decode.string)
  use boot_time <- decode.field("boot_time", decode.int)
  use auto_update_enabled <- decode.field("auto_update_enabled", decode.bool)
  decode.success(StatusSystem(
    api_semver:,
    uptime:,
    boot_time:,
    auto_update_enabled:,
  ))
}

/// Decoder for the `GET /status/power` response body.
pub fn power_decoder() -> Decoder(StatusPower) {
  use state <- decode.field(
    "state",
    api.enum_decoder("power state", [
      #("discharging", Discharging),
      #("charging", Charging),
      #("charged", Charged),
    ]),
  )
  use battery_charge <- decode.field("battery_charge", decode.int)
  use battery_voltage <- decode.field("battery_voltage", decode.int)
  use battery_current <- decode.field("battery_current", decode.int)
  use usb_voltage <- decode.field("usb_voltage", decode.int)
  decode.success(StatusPower(
    state:,
    battery_charge:,
    battery_voltage:,
    battery_current:,
    usb_voltage:,
  ))
}

/// Decoder for the `GET /status` response body.
pub fn status_decoder() -> Decoder(Status) {
  use device <- decode.optional_field(
    "device",
    None,
    decode.optional(device_decoder()),
  )
  use firmware <- decode.optional_field(
    "firmware",
    None,
    decode.optional(firmware_decoder()),
  )
  use system <- decode.optional_field(
    "system",
    None,
    decode.optional(system_decoder()),
  )
  use power <- decode.optional_field(
    "power",
    None,
    decode.optional(power_decoder()),
  )
  decode.success(Status(device:, firmware:, system:, power:))
}

/// Decoder for the `GET /version` response body.
pub fn version_decoder() -> Decoder(String) {
  use api_semver <- decode.field("api_semver", decode.string)
  decode.success(api_semver)
}

/// Build the `GET /status` request without sending it.
pub fn get_status_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/status")
}

/// Get the combined device status.
pub fn get_status(client: Client) -> Result(Status, Error) {
  use req <- result.try(get_status_request(client))
  api.send_json(req, status_decoder())
}

/// Build the `GET /status/device` request without sending it.
pub fn get_device_status_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/status/device")
}

/// Get device hardware info.
pub fn get_device_status(client: Client) -> Result(StatusDevice, Error) {
  use req <- result.try(get_device_status_request(client))
  api.send_json(req, device_decoder())
}

/// Build the `GET /status/firmware` request without sending it.
pub fn get_firmware_status_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/status/firmware")
}

/// Get installed firmware info.
pub fn get_firmware_status(client: Client) -> Result(StatusFirmware, Error) {
  use req <- result.try(get_firmware_status_request(client))
  api.send_json(req, firmware_decoder())
}

/// Build the `GET /status/system` request without sending it.
pub fn get_system_status_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/status/system")
}

/// Get system runtime status.
pub fn get_system_status(client: Client) -> Result(StatusSystem, Error) {
  use req <- result.try(get_system_status_request(client))
  api.send_json(req, system_decoder())
}

/// Build the `GET /status/power` request without sending it.
pub fn get_power_status_request(
  client: Client,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/status/power")
}

/// Get power and battery status.
pub fn get_power_status(client: Client) -> Result(StatusPower, Error) {
  use req <- result.try(get_power_status_request(client))
  api.send_json(req, power_decoder())
}

/// Build the `GET /version` request without sending it.
pub fn get_version_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/version")
}

/// Returns the device's API semver, e.g. "1.1.1".
pub fn get_version(client: Client) -> Result(String, Error) {
  use req <- result.try(get_version_request(client))
  api.send_json(req, version_decoder())
}

/// Build the `GET /screen` request without sending it.
pub fn get_screen_request(
  client: Client,
  screen: ScreenId,
) -> Result(Request(String), Error) {
  let display = case screen {
    FrontScreen -> "0"
    BackScreen -> "1"
  }
  use req <- result.try(api.request_for(client, http.Get, "/screen"))
  Ok(api.set_query(req, [#("display", display)]))
}

/// Capture a display frame. The device sends base64; this returns raw BMP bytes.
pub fn get_screen(client: Client, screen: ScreenId) -> Result(BitArray, Error) {
  use req <- result.try(get_screen_request(client, screen))
  use body <- result.try(api.send_raw(req))
  bit_array.base64_decode(body)
  |> result.replace_error(UnexpectedResponse(200, body))
}

/// Build the `POST /log_dump` request without sending it.
pub fn dump_log_request(
  client: Client,
  filename: Option(String),
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/log_dump"))
  case filename {
    Some(name) -> Ok(api.set_query(req, [#("filename", name)]))
    None -> Ok(req)
  }
}

/// Dump device logs to storage; returns the path of the created dump.
pub fn dump_log(
  client: Client,
  filename: Option(String),
) -> Result(String, Error) {
  use req <- result.try(dump_log_request(client, filename))
  let decoder = {
    use path <- decode.field("path", decode.string)
    decode.success(path)
  }
  api.send_json(req, decoder)
}
