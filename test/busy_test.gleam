import busybar_unofficial
import busybar_unofficial/busy.{
  BusyBarSettings, BusyProfile, BusySnapshot, Infinite, IntervalSettings,
  IntervalTimer, NotStarted, Simple,
}
import gleam/http
import gleam/json
import gleeunit/should

fn client() {
  busybar_unofficial.new("http://192.168.4.1")
}

fn settings() {
  BusyBarSettings(
    theme: "on_air",
    show_work_phase_only: False,
    trigger_smart_home: True,
  )
}

fn settings_json() {
  "{\"theme\":\"on_air\",\"show_work_phase_only\":false,"
  <> "\"trigger_smart_home\":true}"
}

pub fn snapshot_decoder_not_started_test() {
  let body =
    "{\"snapshot\":{\"type\":\"NOT_STARTED\",\"busy_bar_settings\":"
    <> settings_json()
    <> "},\"snapshot_timestamp_ms\":1761582532251}"
  json.parse(body, busy.snapshot_decoder())
  |> should.equal(
    Ok(BusySnapshot(
      snapshot: NotStarted,
      busy_bar_settings: settings(),
      snapshot_timestamp_ms: 1_761_582_532_251,
    )),
  )
}

pub fn snapshot_decoder_simple_test() {
  let body =
    "{\"snapshot\":{\"type\":\"SIMPLE\",\"card_id\":\"c1\","
    <> "\"time_left_ms\":9000,\"is_paused\":false,\"busy_bar_settings\":"
    <> settings_json()
    <> "},\"snapshot_timestamp_ms\":1}"
  let assert Ok(snapshot) = json.parse(body, busy.snapshot_decoder())
  snapshot.snapshot
  |> should.equal(Simple(card_id: "c1", time_left_ms: 9000, is_paused: False))
}

pub fn snapshot_decoder_interval_test() {
  let body =
    "{\"snapshot\":{\"type\":\"INTERVAL\",\"card_id\":\"c2\","
    <> "\"current_interval\":1,\"current_interval_time_total_ms\":60000,"
    <> "\"current_interval_time_left_ms\":42690,\"is_paused\":false,"
    <> "\"interval_settings\":{\"type\":\"INTERVAL\","
    <> "\"interval_work_ms\":120000,\"interval_rest_ms\":60000,"
    <> "\"interval_work_cycles_count\":3,\"is_autostart_enabled\":false},"
    <> "\"busy_bar_settings\":"
    <> settings_json()
    <> "},\"snapshot_timestamp_ms\":1}"
  let assert Ok(snapshot) = json.parse(body, busy.snapshot_decoder())
  let assert busy.Interval(interval_settings: interval, ..) = snapshot.snapshot
  interval.interval_work_ms |> should.equal(120_000)
}

pub fn snapshot_round_trip_test() {
  let snapshot =
    BusySnapshot(
      snapshot: Infinite(card_id: "c9", is_paused: True),
      busy_bar_settings: settings(),
      snapshot_timestamp_ms: 42,
    )
  let encoded = busy.snapshot_to_json(snapshot) |> json.to_string
  json.parse(encoded, busy.snapshot_decoder()) |> should.equal(Ok(snapshot))
}

pub fn profile_round_trip_test() {
  let profile =
    BusyProfile(
      id: "00000000-0000-0000-0000-000000000000",
      title: "study",
      sort_order: -1,
      timer_settings: IntervalTimer(IntervalSettings(
        interval_work_ms: 120_000,
        interval_rest_ms: 60_000,
        interval_work_cycles_count: 3,
        is_autostart_enabled: False,
      )),
      busy_bar_settings: settings(),
      profile_timestamp_ms: 1_761_582_532_251,
    )
  let encoded = busy.profile_to_json(profile) |> json.to_string
  json.parse(encoded, busy.profile_decoder()) |> should.equal(Ok(profile))
}

pub fn get_profile_request_slot_path_test() {
  let assert Ok(req) = busy.get_profile_request(client(), busy.CustomSlot)
  req.path |> should.equal("/busybar/busy/profiles/custom")
}

pub fn set_snapshot_request_is_put_test() {
  let snapshot =
    BusySnapshot(
      snapshot: NotStarted,
      busy_bar_settings: settings(),
      snapshot_timestamp_ms: 1,
    )
  let assert Ok(req) = busy.set_snapshot_request(client(), snapshot)
  req.method |> should.equal(http.Put)
  req.path |> should.equal("/busybar/busy/snapshot")
}
