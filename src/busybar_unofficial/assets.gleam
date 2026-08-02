//// Uploading app assets (images, animations, sounds) to the device.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/http
import gleam/http/request.{type Request}
import gleam/result

pub fn upload_request(
  client: Client,
  application_name: String,
  file_name: String,
  data: BitArray,
) -> Result(Request(BitArray), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/assets/upload"))
  Ok(
    req
    |> api.set_query([
      #("application_name", application_name),
      #("file", file_name),
    ])
    |> request.set_header("content-type", "application/octet-stream")
    |> request.set_body(data),
  )
}

/// Upload one asset file for an application.
pub fn upload(
  client: Client,
  application_name: String,
  file_name: String,
  data: BitArray,
) -> Result(Nil, Error) {
  use req <- result.try(upload_request(
    client,
    application_name,
    file_name,
    data,
  ))
  api.send_bits_expect_success(req)
}

pub fn delete_request(
  client: Client,
  application_name: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Delete, "/assets/upload"))
  Ok(api.set_query(req, [#("application_name", application_name)]))
}

/// Delete ALL assets uploaded for an application.
pub fn delete(client: Client, application_name: String) -> Result(Nil, Error) {
  use req <- result.try(delete_request(client, application_name))
  api.send_expect_success(req)
}
