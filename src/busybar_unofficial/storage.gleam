//// Files on the device's storage partition.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/result

pub type StorageEntry {
  FileEntry(name: String)
  DirEntry(name: String)
}

pub type StorageStatus {
  StorageStatus(used_bytes: Int, free_bytes: Int, total_bytes: Int)
}

fn entry_decoder() -> Decoder(StorageEntry) {
  use kind <- decode.field("type", decode.string)
  use name <- decode.field("name", decode.string)
  case kind {
    "file" -> decode.success(FileEntry(name))
    "dir" -> decode.success(DirEntry(name))
    _ -> decode.failure(FileEntry(name), "storage entry")
  }
}

pub fn list_decoder() -> Decoder(List(StorageEntry)) {
  use entries <- decode.field("list", decode.list(entry_decoder()))
  decode.success(entries)
}

pub fn status_decoder() -> Decoder(StorageStatus) {
  use used_bytes <- decode.field("used_bytes", decode.int)
  use free_bytes <- decode.field("free_bytes", decode.int)
  use total_bytes <- decode.field("total_bytes", decode.int)
  decode.success(StorageStatus(used_bytes:, free_bytes:, total_bytes:))
}

pub fn write_request(
  client: Client,
  path: String,
  data: BitArray,
) -> Result(Request(BitArray), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/storage/write"))
  Ok(
    req
    |> api.set_query([#("path", path)])
    |> request.set_header("content-type", "application/octet-stream")
    |> request.set_body(data),
  )
}

/// Write a file to device storage.
pub fn write(
  client: Client,
  path: String,
  data: BitArray,
) -> Result(Nil, Error) {
  use req <- result.try(write_request(client, path, data))
  api.send_bits_expect_success(req)
}

pub fn read_request(
  client: Client,
  path: String,
) -> Result(Request(BitArray), Error) {
  use req <- result.try(api.request_for(client, http.Get, "/storage/read"))
  Ok(req |> api.set_query([#("path", path)]) |> request.set_body(<<>>))
}

/// Read a file from device storage.
pub fn read(client: Client, path: String) -> Result(BitArray, Error) {
  use req <- result.try(read_request(client, path))
  api.send_bits_raw(req)
}

pub fn list_request(
  client: Client,
  path: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Get, "/storage/list"))
  Ok(api.set_query(req, [#("path", path)]))
}

pub fn list(client: Client, path: String) -> Result(List(StorageEntry), Error) {
  use req <- result.try(list_request(client, path))
  api.send_json(req, list_decoder())
}

pub fn remove_request(
  client: Client,
  path: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Delete, "/storage/remove"))
  Ok(api.set_query(req, [#("path", path)]))
}

pub fn remove(client: Client, path: String) -> Result(Nil, Error) {
  use req <- result.try(remove_request(client, path))
  api.send_expect_success(req)
}

pub fn mkdir_request(
  client: Client,
  path: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/storage/mkdir"))
  Ok(api.set_query(req, [#("path", path)]))
}

pub fn mkdir(client: Client, path: String) -> Result(Nil, Error) {
  use req <- result.try(mkdir_request(client, path))
  api.send_expect_success(req)
}

pub fn rename_request(
  client: Client,
  path: String,
  new_path: String,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Post, "/storage/rename"))
  Ok(api.set_query(req, [#("path", path), #("new_path", new_path)]))
}

pub fn rename(
  client: Client,
  path: String,
  new_path: String,
) -> Result(Nil, Error) {
  use req <- result.try(rename_request(client, path, new_path))
  api.send_expect_success(req)
}

pub fn get_status_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/storage/status")
}

pub fn get_status(client: Client) -> Result(StorageStatus, Error) {
  use req <- result.try(get_status_request(client))
  api.send_json(req, status_decoder())
}
