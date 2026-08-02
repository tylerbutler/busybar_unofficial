import busybar_unofficial
import busybar_unofficial/settings.{
  AccessInfo, AccessKey, KeySettings, UsbInterface,
}
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn press_key_request_test() {
  let assert Ok(req) = settings.press_key_request(client(), KeySettings)
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/input")
  req.query |> should.equal(Some("key=settings"))
}

pub fn access_info_decoder_test() {
  json.parse("{\"mode\":\"key\",\"key_valid\":true}", settings.access_decoder())
  |> should.equal(Ok(AccessInfo(mode: AccessKey, key_valid: Some(True))))
}

pub fn access_info_decoder_without_key_valid_test() {
  json.parse("{\"mode\":\"key\"}", settings.access_decoder())
  |> should.equal(Ok(AccessInfo(mode: AccessKey, key_valid: None)))
}

pub fn set_access_request_with_key_test() {
  let assert Ok(req) =
    settings.set_access_request(client(), AccessKey, Some("1234"))
  req.query |> should.equal(Some("mode=key&key=1234"))
}

pub fn set_access_request_without_key_test() {
  let assert Ok(req) =
    settings.set_access_request(client(), settings.AccessDisabled, None)
  req.query |> should.equal(Some("mode=disabled"))
}

pub fn name_decoder_test() {
  json.parse("{\"name\":\"BUSY bar\"}", settings.name_decoder())
  |> should.equal(Ok("BUSY bar"))
}

pub fn set_name_request_has_json_body_test() {
  let assert Ok(req) = settings.set_name_request(client(), "desk bar")
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/name")
  req.body |> should.equal("{\"name\":\"desk bar\"}")
}

pub fn transport_decoder_test() {
  json.parse("{\"type\":\"usb\"}", settings.transport_decoder())
  |> should.equal(Ok(UsbInterface))
}
