import busybar_unofficial
import busybar_unofficial/assets
import gleam/http
import gleam/http/request
import gleam/option.{Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn upload_request_test() {
  let assert Ok(req) =
    assets.upload_request(client(), "my_app", "logo.px", <<1, 2>>)
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/assets/upload")
  req.query |> should.equal(Some("application_name=my_app&file=logo.px"))
  req.body |> should.equal(<<1, 2>>)
  request.get_header(req, "content-type")
  |> should.equal(Ok("application/octet-stream"))
}

pub fn delete_request_test() {
  let assert Ok(req) = assets.delete_request(client(), "my_app")
  req.method |> should.equal(http.Delete)
  req.path |> should.equal("/busybar/assets/upload")
  req.query |> should.equal(Some("application_name=my_app"))
}
