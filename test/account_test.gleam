import busybar_unofficial
import busybar_unofficial/account.{AccountBackend, Connected, DefaultCert}
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn get_info_request_test() {
  let assert Ok(req) = account.get_info_request(client())
  req.method |> should.equal(http.Get)
  req.path |> should.equal("/busybar/account/info")
}

pub fn info_decoder_linked_test() {
  let body =
    "{\"linked\":true,\"id\":\"abc\",\"email\":\"t@example.com\","
    <> "\"user_id\":\"u1\"}"
  let assert Ok(info) = json.parse(body, account.info_decoder())
  info.linked |> should.equal(True)
  info.email |> should.equal(Some("t@example.com"))
}

pub fn info_decoder_unlinked_defaults_test() {
  let assert Ok(info) = json.parse("{}", account.info_decoder())
  info.linked |> should.equal(False)
  info.id |> should.equal(None)
}

pub fn status_decoder_test() {
  json.parse("{\"status\":\"connected\"}", account.status_decoder())
  |> should.equal(Ok(Connected))
}

pub fn backend_decoder_test() {
  let body =
    "{\"server_url\":\"mqtts://x\",\"client_cert_type\":\"default\","
    <> "\"ignore_server_cert\":false}"
  json.parse(body, account.backend_decoder())
  |> should.equal(
    Ok(AccountBackend(
      server_url: "mqtts://x",
      client_cert_type: DefaultCert,
      ignore_server_cert: False,
    )),
  )
}
