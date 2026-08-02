import busybar_unofficial
import busybar_unofficial/smart_home.{
  CompletedSuccessfully, PairingAttempt, StartupLast,
}
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn pairing_info_decoder_test() {
  let body =
    "{\"fabric_count\":1,\"latest_pairing_status\":"
    <> "{\"value\":\"completed_successfully\",\"timestamp\":1769437579}}"
  let assert Ok(info) = json.parse(body, smart_home.pairing_info_decoder())
  info.fabric_count |> should.equal(1)
  info.latest_pairing_status
  |> should.equal(
    Some(PairingAttempt(
      value: CompletedSuccessfully,
      timestamp: Some(1_769_437_579),
    )),
  )
}

pub fn pairing_info_decoder_empty_test() {
  let assert Ok(info) = json.parse("{}", smart_home.pairing_info_decoder())
  info.fabric_count |> should.equal(0)
  info.latest_pairing_status |> should.equal(None)
}

pub fn pairing_payload_decoder_test() {
  let body =
    "{\"available_until\":\"1769437579000\",\"qr_code\":\"MT:YNDA\","
    <> "\"manual_code\":\"1155-360-0377\"}"
  let assert Ok(payload) =
    json.parse(body, smart_home.pairing_payload_decoder())
  payload.qr_code |> should.equal(Some("MT:YNDA"))
}

pub fn switch_decoder_test() {
  json.parse("{\"state\":false}", smart_home.switch_decoder())
  |> should.equal(Ok(False))
}

pub fn set_switch_request_state_only_test() {
  let assert Ok(req) = smart_home.set_switch_request(client(), Some(True), None)
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/smart_home/switch")
  req.body |> should.equal("{\"state\":true}")
}

pub fn set_switch_request_startup_test() {
  let assert Ok(req) =
    smart_home.set_switch_request(client(), None, Some(StartupLast))
  req.body |> should.equal("{\"startup\":\"last\"}")
}

pub fn unpair_all_request_test() {
  let assert Ok(req) = smart_home.unpair_all_request(client())
  req.method |> should.equal(http.Delete)
  req.path |> should.equal("/busybar/smart_home/pairing")
}
