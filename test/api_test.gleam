import busybar_unofficial.{ApiError, NetworkError, UnexpectedResponse}
import busybar_unofficial/internal/api
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

pub fn new_client_has_no_token_test() {
  let client = busybar_unofficial.new("http://192.168.4.1")
  client.base_url |> should.equal("http://192.168.4.1")
  client.token |> should.equal(None)
}

pub fn with_token_sets_token_test() {
  let client =
    busybar_unofficial.new("http://192.168.4.1")
    |> busybar_unofficial.with_token("secret")
  client.token |> should.equal(Some("secret"))
}

pub fn request_for_builds_method_host_and_path_test() {
  let client = busybar_unofficial.new("http://192.168.4.1")
  let assert Ok(req) = api.request_for(client, http.Post, "/input")
  req.method |> should.equal(http.Post)
  req.host |> should.equal("192.168.4.1")
  req.path |> should.equal("/busybar/input")
  request.get_header(req, "authorization") |> should.equal(Error(Nil))
}

pub fn request_for_strips_trailing_slash_test() {
  let client = busybar_unofficial.new("http://192.168.4.1/")
  let assert Ok(req) = api.request_for(client, http.Get, "/status")
  req.path |> should.equal("/busybar/status")
}

pub fn request_for_adds_bearer_token_test() {
  let client =
    busybar_unofficial.new("http://192.168.4.1")
    |> busybar_unofficial.with_token("secret")
  let assert Ok(req) = api.request_for(client, http.Get, "/status")
  request.get_header(req, "authorization")
  |> should.equal(Ok("Bearer secret"))
}

pub fn request_for_invalid_base_url_is_network_error_test() {
  let client = busybar_unofficial.new("not a url")
  let assert Error(NetworkError(_)) =
    api.request_for(client, http.Get, "/status")
}

pub fn handle_json_decodes_2xx_body_test() {
  let resp =
    response.new(200)
    |> response.set_body("{\"name\":\"BUSY bar\"}")
  let decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }
  api.handle_json(resp, decoder) |> should.equal(Ok("BUSY bar"))
}

pub fn handle_json_malformed_2xx_body_is_unexpected_test() {
  let resp = response.new(200) |> response.set_body("not json")
  api.handle_json(resp, decode.string)
  |> should.equal(Error(UnexpectedResponse(200, "not json")))
}

pub fn handle_json_error_body_is_api_error_test() {
  let resp =
    response.new(400)
    |> response.set_body("{\"error\":\"Invalid parameter\",\"code\":400}")
  api.handle_json(resp, decode.string)
  |> should.equal(Error(ApiError(400, "Invalid parameter")))
}

pub fn handle_json_error_without_code_uses_http_status_test() {
  let resp =
    response.new(503)
    |> response.set_body("{\"error\":\"BLE unavailable\"}")
  api.handle_json(resp, decode.string)
  |> should.equal(Error(ApiError(503, "BLE unavailable")))
}

pub fn handle_json_undecodable_error_body_is_unexpected_test() {
  let resp = response.new(500) |> response.set_body("boom")
  api.handle_json(resp, decode.string)
  |> should.equal(Error(UnexpectedResponse(500, "boom")))
}

pub fn handle_success_accepts_any_2xx_test() {
  let resp = response.new(200) |> response.set_body("{\"result\":\"OK\"}")
  api.handle_success(resp) |> should.equal(Ok(Nil))
}

pub fn handle_raw_returns_2xx_body_test() {
  let resp = response.new(200) |> response.set_body("Qk0abcd")
  api.handle_raw(resp) |> should.equal(Ok("Qk0abcd"))
}

pub fn handle_bits_returns_2xx_body_test() {
  let resp = response.new(200) |> response.set_body(<<1, 2, 3>>)
  api.handle_bits(resp) |> should.equal(Ok(<<1, 2, 3>>))
}

pub fn handle_bits_decodes_json_error_body_test() {
  let resp =
    response.new(400)
    |> response.set_body(<<"{\"error\":\"bad path\",\"code\":400}":utf8>>)
  api.handle_bits(resp) |> should.equal(Error(ApiError(400, "bad path")))
}

pub fn enum_decoder_maps_known_values_test() {
  let decoder =
    api.enum_decoder("power state", [
      #("charging", "CHARGING"),
      #("charged", "CHARGED"),
    ])
  json.parse("\"charged\"", decoder) |> should.equal(Ok("CHARGED"))
}

pub fn enum_decoder_rejects_unknown_values_test() {
  let decoder = api.enum_decoder("power state", [#("charging", "CHARGING")])
  let assert Error(_) = json.parse("\"weird\"", decoder)
}

pub fn compact_drops_none_props_test() {
  api.compact([
    #("a", Some(json.int(1))),
    #("b", None),
    #("c", Some(json.string("x"))),
  ])
  |> should.equal([#("a", json.int(1)), #("c", json.string("x"))])
}
