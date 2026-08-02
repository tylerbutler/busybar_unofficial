import busybar_unofficial
import busybar_unofficial/updater.{AutoupdateSettings}
import gleam/http
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn update_status_decoder_test() {
  let body =
    "{\"install\":{\"is_allowed\":true,\"event\":\"action_progress\","
    <> "\"action\":\"download\",\"status\":\"ok\",\"detail\":\"\","
    <> "\"download\":{\"speed_bytes_per_sec\":1024,\"received_bytes\":10,"
    <> "\"total_bytes\":100}},"
    <> "\"check\":{\"available_version\":\"1.2.0\",\"event\":\"stop\","
    <> "\"status\":\"available\"}}"
  let assert Ok(status) = json.parse(body, updater.update_status_decoder())
  let assert Some(install) = status.install
  install.action |> should.equal(Some("download"))
  let assert Some(download) = install.download
  download.total_bytes |> should.equal(Some(100))
  let assert Some(check) = status.check
  check.available_version |> should.equal(Some("1.2.0"))
}

pub fn update_status_decoder_empty_test() {
  let assert Ok(status) = json.parse("{}", updater.update_status_decoder())
  status.install |> should.equal(None)
  status.check |> should.equal(None)
}

pub fn changelog_decoder_test() {
  json.parse("{\"changelog\":\"- fixes\"}", updater.changelog_decoder())
  |> should.equal(Ok("- fixes"))
}

pub fn install_request_test() {
  let assert Ok(req) = updater.install_request(client(), "1.2.0")
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/update/install")
  req.query |> should.equal(Some("version=1.2.0"))
}

pub fn autoupdate_decoder_test() {
  let body =
    "{\"is_enabled\":true,\"interval_start\":\"00:00\","
    <> "\"interval_end\":\"08:00\"}"
  json.parse(body, updater.autoupdate_decoder())
  |> should.equal(
    Ok(AutoupdateSettings(
      is_enabled: Some(True),
      interval_start: Some("00:00"),
      interval_end: Some("08:00"),
    )),
  )
}

pub fn set_autoupdate_request_test() {
  let assert Ok(req) =
    updater.set_autoupdate_request(
      client(),
      AutoupdateSettings(
        is_enabled: Some(False),
        interval_start: None,
        interval_end: None,
      ),
    )
  req.body |> should.equal("{\"is_enabled\":false}")
}

pub fn upload_firmware_request_test() {
  let assert Ok(req) = updater.upload_firmware_request(client(), <<1, 2, 3>>)
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/update")
  req.body |> should.equal(<<1, 2, 3>>)
}

pub fn abort_download_request_test() {
  let assert Ok(req) = updater.abort_download_request(client())
  req.path |> should.equal("/busybar/update/abort_download")
}
