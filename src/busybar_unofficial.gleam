//// Unofficial Gleam client for the BUSY Bar HTTP API.

import gleam/option.{type Option, None, Some}

/// A handle to one BUSY Bar device (or the cloud proxy).
pub type Client {
  Client(base_url: String, token: Option(String))
}

/// Create a client for a device, e.g. `new("http://192.168.4.1")`.
pub fn new(base_url: String) -> Client {
  Client(base_url: base_url, token: None)
}

/// Attach a BUSY Cloud BAR-scope API token, sent as a bearer token.
pub fn with_token(client: Client, token: String) -> Client {
  Client(..client, token: Some(token))
}

/// All errors returned by this library.
pub type Error {
  /// Transport failure: could not connect, timeout, non-UTF-8 response.
  NetworkError(reason: String)
  /// The device returned an error response (the spec's Error schema).
  /// `code` is the body's code when present, otherwise the HTTP status.
  ApiError(code: Int, message: String)
  /// A response this library could not interpret.
  UnexpectedResponse(status: Int, body: String)
}
