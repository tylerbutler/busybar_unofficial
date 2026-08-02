import busybar_unofficial
import busybar_unofficial/time.{Timezone}
import gleam/http
import gleam/json
import gleam/option.{Some}
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

pub fn timestamp_decoder_test() {
  json.parse(
    "{\"timestamp\":\"2025-10-02T14:30:45+04:00\"}",
    time.timestamp_decoder(),
  )
  |> should.equal(Ok("2025-10-02T14:30:45+04:00"))
}

pub fn set_timestamp_request_test() {
  let assert Ok(req) =
    time.set_timestamp_request(client(), "2025-10-02T14:30:45+02:00")
  req.method |> should.equal(http.Post)
  req.path |> should.equal("/busybar/time/timestamp")
  req.query |> should.equal(Some("timestamp=2025-10-02T14%3A30%3A45%2B02%3A00"))
}

pub fn timezone_decoder_test() {
  json.parse(
    "{\"name\":\"Bangalore\",\"offset\":\"+05:30\",\"abbr\":\"IST\"}",
    time.timezone_decoder(),
  )
  |> should.equal(
    Ok(Timezone(name: "Bangalore", offset: "+05:30", abbr: "IST")),
  )
}

pub fn tzlist_decoder_test() {
  let body =
    "{\"list\":[{\"name\":\"A\",\"offset\":\"+01:00\",\"abbr\":\"A\"},"
    <> "{\"name\":\"B\",\"offset\":\"+02:00\",\"abbr\":\"B\"}]}"
  let assert Ok(zones) = json.parse(body, time.tzlist_decoder())
  zones
  |> should.equal([
    Timezone(name: "A", offset: "+01:00", abbr: "A"),
    Timezone(name: "B", offset: "+02:00", abbr: "B"),
  ])
}

pub fn set_timezone_request_test() {
  let assert Ok(req) = time.set_timezone_request(client(), "Bangalore")
  req.query |> should.equal(Some("timezone=Bangalore"))
}
