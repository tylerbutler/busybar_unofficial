import busybar_unofficial
import busybar_unofficial/storage.{DirEntry, FileEntry, StorageStatus}
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option.{Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn write_request_test() {
  let assert Ok(req) =
    storage.write_request(client(), "apps/data.txt", <<"hi":utf8>>)
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/storage/write")
  req.query |> should.equal(Some("path=apps%2Fdata.txt"))
  req.body |> should.equal(<<"hi":utf8>>)
  request.get_header(req, "content-type")
  |> should.equal(Ok("application/octet-stream"))
}

pub fn read_request_test() {
  let assert Ok(req) = storage.read_request(client(), "apps/data.txt")
  req.method |> should.equal(http.Get)
  req.path |> should.equal("/busybar/storage/read")
}

pub fn list_decoder_test() {
  let body =
    "{\"list\":[{\"type\":\"file\",\"name\":\"a.txt\"},"
    <> "{\"type\":\"dir\",\"name\":\"sub\"}]}"
  json.parse(body, storage.list_decoder())
  |> should.equal(Ok([FileEntry("a.txt"), DirEntry("sub")]))
}

pub fn rename_request_test() {
  let assert Ok(req) = storage.rename_request(client(), "a.txt", "b.txt")
  req.query |> should.equal(Some("path=a.txt&new_path=b.txt"))
}

pub fn status_decoder_test() {
  let body =
    "{\"used_bytes\":123456,\"free_bytes\":654321,\"total_bytes\":777777}"
  json.parse(body, storage.status_decoder())
  |> should.equal(
    Ok(StorageStatus(
      used_bytes: 123_456,
      free_bytes: 654_321,
      total_bytes: 777_777,
    )),
  )
}

pub fn mkdir_request_test() {
  let assert Ok(req) = storage.mkdir_request(client(), "newdir")
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/storage/mkdir")
  req.query |> should.equal(Some("path=newdir"))
}

pub fn remove_request_test() {
  let assert Ok(req) = storage.remove_request(client(), "a.txt")
  req.method |> should.equal(http.Delete)
  req.path |> should.equal("/busybar/storage/remove")
}
