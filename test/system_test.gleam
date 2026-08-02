import busybar_unofficial
import busybar_unofficial/system.{
  BackScreen, Charging, Discharging, Secure, StatusPower,
}
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn get_status_request_test() {
  let assert Ok(req) = system.get_status_request(client())
  req.method |> should.equal(http.Get)
  req.path |> should.equal("/busybar/status")
}

pub fn power_decoder_test() {
  let body =
    "{\"state\":\"discharging\",\"battery_charge\":99,\"battery_voltage\":4183,"
    <> "\"battery_current\":-180,\"usb_voltage\":4843}"
  json.parse(body, system.power_decoder())
  |> should.equal(
    Ok(StatusPower(
      state: Discharging,
      battery_charge: 99,
      battery_voltage: 4183,
      battery_current: -180,
      usb_voltage: 4843,
    )),
  )
}

pub fn power_decoder_rejects_unknown_state_test() {
  let body =
    "{\"state\":\"exploded\",\"battery_charge\":1,\"battery_voltage\":1,"
    <> "\"battery_current\":1,\"usb_voltage\":1}"
  let assert Error(_) = json.parse(body, system.power_decoder())
}

pub fn device_decoder_optional_fields_test() {
  let body =
    "{\"serial_number\":\"2036\",\"usb_mac\":\"0c:fa:22:21:2a:31\","
    <> "\"otp_valid\":true,\"firmware_security\":\"secure\"}"
  let assert Ok(device) = json.parse(body, system.device_decoder())
  device.serial_number |> should.equal("2036")
  device.wifi_mac |> should.equal(None)
  device.firmware_security |> should.equal(Secure)
}

pub fn firmware_decoder_test() {
  let body =
    "{\"version\":\"1.0.0\",\"target\":22,\"branch\":\"main\","
    <> "\"build_date\":\"2024-01-01\",\"commit_hash\":\"abc123\","
    <> "\"intercom_version\":\"abc123de\",\"nwp_version\":\"1711.2\"}"
  let assert Ok(firmware) = json.parse(body, system.firmware_decoder())
  firmware.version |> should.equal("1.0.0")
  firmware.target |> should.equal(22)
  firmware.nwp_version |> should.equal(Some("1711.2"))
  firmware.matter_version |> should.equal(None)
}

pub fn system_decoder_test() {
  let body =
    "{\"api_semver\":\"0.0.0\",\"uptime\":\"00d 00h 04m 13s\","
    <> "\"boot_time\":1767225600,\"auto_update_enabled\":true}"
  let assert Ok(sys) = json.parse(body, system.system_decoder())
  sys.uptime |> should.equal("00d 00h 04m 13s")
  sys.auto_update_enabled |> should.equal(True)
}

pub fn status_decoder_nests_sections_test() {
  let body =
    "{\"power\":{\"state\":\"charging\",\"battery_charge\":50,"
    <> "\"battery_voltage\":4000,\"battery_current\":100,\"usb_voltage\":5000}}"
  let assert Ok(status) = json.parse(body, system.status_decoder())
  status.device |> should.equal(None)
  let assert Some(power) = status.power
  power.state |> should.equal(Charging)
}

pub fn get_screen_request_has_display_query_test() {
  let assert Ok(req) = system.get_screen_request(client(), BackScreen)
  req.path |> should.equal("/busybar/screen")
  req.query |> should.equal(Some("display=1"))
}

pub fn dump_log_request_test() {
  let assert Ok(req) = system.dump_log_request(client(), Some("crash"))
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/log_dump")
  req.query |> should.equal(Some("filename=crash"))
}

pub fn dump_log_request_without_filename_test() {
  let assert Ok(req) = system.dump_log_request(client(), None)
  req.query |> should.equal(None)
}

pub fn version_decoder_unwraps_semver_test() {
  json.parse("{\"api_semver\":\"1.2.3\"}", system.version_decoder())
  |> should.equal(Ok("1.2.3"))
}
