import busybar_unofficial
import busybar_unofficial/ble.{BleConnected, BleStatus}
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn enable_request_test() {
  let assert Ok(req) = ble.enable_request(client())
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/ble/enable")
}

pub fn unpair_request_test() {
  let assert Ok(req) = ble.unpair_request(client())
  req.method |> should.equal(http.Delete)
  req.path |> should.equal("/busybar/ble/pairing")
}

pub fn status_decoder_connected_test() {
  json.parse(
    "{\"status\":\"connected\",\"address\":\"50:DA:D6:FE:DD:A9\"}",
    ble.status_decoder(),
  )
  |> should.equal(
    Ok(BleStatus(state: BleConnected, address: Some("50:DA:D6:FE:DD:A9"))),
  )
}

pub fn status_decoder_internal_error_test() {
  let assert Ok(status) =
    json.parse("{\"status\":\"internal error\"}", ble.status_decoder())
  status.state |> should.equal(ble.BleInternalError)
  status.address |> should.equal(None)
}
