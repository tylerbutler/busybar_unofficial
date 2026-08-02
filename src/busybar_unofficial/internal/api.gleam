//// Shared request/response plumbing. Internal — not part of the public API.

import busybar_unofficial.{
  type Client, type Error, ApiError, NetworkError, UnexpectedResponse,
}
import gleam/bit_array
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Build a request for an API path (e.g. "/status"). Prepends "/busybar".
pub fn request_for(
  client: Client,
  method: http.Method,
  path: String,
) -> Result(Request(String), Error) {
  let base = case string.ends_with(client.base_url, "/") {
    True -> string.drop_end(client.base_url, 1)
    False -> client.base_url
  }
  case request.to(base <> "/busybar" <> path) {
    Error(Nil) -> Error(NetworkError("invalid base URL: " <> client.base_url))
    Ok(req) -> {
      let req = request.set_method(req, method) |> request.set_body("")
      case client.token {
        Some(token) ->
          Ok(request.set_header(req, "authorization", "Bearer " <> token))
        None -> Ok(req)
      }
    }
  }
}

/// Decode a JSON string enum into a custom type.
pub fn enum_decoder(
  expected: String,
  variants: List(#(String, a)),
) -> Decoder(a) {
  let assert [#(_, placeholder), ..] = variants
  decode.string
  |> decode.then(fn(value) {
    case list.key_find(variants, value) {
      Ok(mapped) -> decode.success(mapped)
      Error(Nil) -> decode.failure(placeholder, expected)
    }
  })
}

/// Drop None-valued props so encoders omit absent optional fields.
pub fn compact(props: List(#(String, Option(Json)))) -> List(#(String, Json)) {
  list.filter_map(props, fn(prop) {
    case prop.1 {
      Some(value) -> Ok(#(prop.0, value))
      None -> Error(Nil)
    }
  })
}

fn network_error(error: httpc.HttpError) -> Error {
  NetworkError(string.inspect(error))
}

fn api_error(status: Int, body: String) -> Error {
  let decoder = {
    use message <- decode.field("error", decode.string)
    use code <- decode.optional_field("code", status, decode.int)
    decode.success(ApiError(code, message))
  }
  case json.parse(body, decoder) {
    Ok(error) -> error
    Error(_) -> UnexpectedResponse(status, body)
  }
}

fn is_success(status: Int) -> Bool {
  status >= 200 && status < 300
}

/// Interpret a response whose 2xx body is JSON decoded by `decoder`.
pub fn handle_json(
  resp: Response(String),
  decoder: Decoder(t),
) -> Result(t, Error) {
  case is_success(resp.status) {
    True ->
      json.parse(resp.body, decoder)
      |> result.replace_error(UnexpectedResponse(resp.status, resp.body))
    False -> Error(api_error(resp.status, resp.body))
  }
}

/// Interpret a response where any 2xx means success (SuccessResponse).
pub fn handle_success(resp: Response(String)) -> Result(Nil, Error) {
  case is_success(resp.status) {
    True -> Ok(Nil)
    False -> Error(api_error(resp.status, resp.body))
  }
}

/// Interpret a response whose 2xx body is returned verbatim.
pub fn handle_raw(resp: Response(String)) -> Result(String, Error) {
  case is_success(resp.status) {
    True -> Ok(resp.body)
    False -> Error(api_error(resp.status, resp.body))
  }
}

/// Interpret a binary response; error bodies are JSON in the bits.
pub fn handle_bits(resp: Response(BitArray)) -> Result(BitArray, Error) {
  case is_success(resp.status) {
    True -> Ok(resp.body)
    False -> {
      let body =
        bit_array.to_string(resp.body) |> result.unwrap("<binary body>")
      Error(api_error(resp.status, body))
    }
  }
}

pub fn send_json(
  req: Request(String),
  decoder: Decoder(t),
) -> Result(t, Error) {
  httpc.send(req)
  |> result.map_error(network_error)
  |> result.try(handle_json(_, decoder))
}

pub fn send_expect_success(req: Request(String)) -> Result(Nil, Error) {
  httpc.send(req)
  |> result.map_error(network_error)
  |> result.try(handle_success)
}

pub fn send_raw(req: Request(String)) -> Result(String, Error) {
  httpc.send(req)
  |> result.map_error(network_error)
  |> result.try(handle_raw)
}

pub fn send_bits_expect_success(req: Request(BitArray)) -> Result(Nil, Error) {
  httpc.send_bits(req)
  |> result.map_error(network_error)
  |> result.try(fn(resp) { handle_bits(resp) |> result.replace(Nil) })
}

pub fn send_bits_raw(req: Request(BitArray)) -> Result(BitArray, Error) {
  httpc.send_bits(req)
  |> result.map_error(network_error)
  |> result.try(handle_bits)
}

/// Attach a JSON body and content-type header to a request.
pub fn with_json_body(req: Request(String), body: Json) -> Request(String) {
  req
  |> request.set_body(json.to_string(body))
  |> request.set_header("content-type", "application/json")
}
