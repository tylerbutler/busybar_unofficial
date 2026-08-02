import busybar_unofficial
import busybar_unofficial/wifi.{StateConnected, StateDisconnected}
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

pub fn status_decoder_disconnected_test() {
  let assert Ok(status) =
    json.parse("{\"state\":\"disconnected\"}", wifi.status_decoder())
  status.state |> should.equal(StateDisconnected)
  status.ssid |> should.equal(None)
}

pub fn status_decoder_connected_test() {
  let body =
    "{\"state\":\"connected\",\"ssid\":\"MyWifi\",\"bssid\":\"EC:5A:00:0B:55:1D\","
    <> "\"channel\":3,\"rssi\":-43,\"security\":\"WPA3\","
    <> "\"ip_config\":{\"ip_method\":\"dhcp\",\"ip_type\":\"ipv4\","
    <> "\"address\":\"192.168.1.7\"}}"
  let assert Ok(status) = json.parse(body, wifi.status_decoder())
  status.state |> should.equal(StateConnected)
  status.ssid |> should.equal(Some("MyWifi"))
  status.rssi |> should.equal(Some(-43))
  let assert Some(ip) = status.ip_config
  ip.address |> should.equal(Some("192.168.1.7"))
}

pub fn get_status_request_test() {
  let client = busybar_unofficial.new("http://192.168.4.1")
  let assert Ok(req) = wifi.get_status_request(client)
  req.method |> should.equal(http.Get)
  req.path |> should.equal("/busybar/wifi/status")
}
