//// Busy timers: the live snapshot and the two device profiles.

import busybar_unofficial.{type Client, type Error}
import busybar_unofficial/internal/api
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/json.{type Json}
import gleam/list
import gleam/result

/// Presentation settings shared by snapshots and profiles.
pub type BusyBarSettings {
  BusyBarSettings(
    theme: String,
    show_work_phase_only: Bool,
    trigger_smart_home: Bool,
  )
}

/// Configuration for an interval (work/rest) timer.
pub type IntervalSettings {
  IntervalSettings(
    interval_work_ms: Int,
    interval_rest_ms: Int,
    interval_work_cycles_count: Int,
    is_autostart_enabled: Bool,
  )
}

/// The timer configuration stored in a profile.
pub type TimerSettings {
  InfiniteTimer
  SimpleTimer(total_time_ms: Int)
  IntervalTimer(settings: IntervalSettings)
}

/// The current state of the busy timer.
pub type Snapshot {
  NotStarted
  Infinite(card_id: String, is_paused: Bool)
  Simple(card_id: String, time_left_ms: Int, is_paused: Bool)
  Interval(
    card_id: String,
    current_interval: Int,
    current_interval_time_total_ms: Int,
    current_interval_time_left_ms: Int,
    is_paused: Bool,
    interval_settings: IntervalSettings,
  )
}

/// A full busy-timer snapshot: the timer state, its settings, and the
/// timestamp (Unix ms) at which the snapshot was taken.
pub type BusySnapshot {
  BusySnapshot(
    snapshot: Snapshot,
    busy_bar_settings: BusyBarSettings,
    snapshot_timestamp_ms: Int,
  )
}

/// A stored timer profile.
pub type BusyProfile {
  BusyProfile(
    id: String,
    title: String,
    sort_order: Int,
    timer_settings: TimerSettings,
    busy_bar_settings: BusyBarSettings,
    profile_timestamp_ms: Int,
  )
}

/// The device's two profile slots.
pub type ProfileSlot {
  BusySlot
  CustomSlot
}

fn slot_to_string(slot: ProfileSlot) -> String {
  case slot {
    BusySlot -> "busy"
    CustomSlot -> "custom"
  }
}

/// Decoder for `BusyBarSettings` JSON.
pub fn settings_decoder() -> Decoder(BusyBarSettings) {
  use theme <- decode.field("theme", decode.string)
  use show_work_phase_only <- decode.field("show_work_phase_only", decode.bool)
  use trigger_smart_home <- decode.field("trigger_smart_home", decode.bool)
  decode.success(BusyBarSettings(
    theme:,
    show_work_phase_only:,
    trigger_smart_home:,
  ))
}

/// Decoder for `IntervalSettings` JSON.
pub fn interval_settings_decoder() -> Decoder(IntervalSettings) {
  use interval_work_ms <- decode.field("interval_work_ms", decode.int)
  use interval_rest_ms <- decode.field("interval_rest_ms", decode.int)
  use interval_work_cycles_count <- decode.field(
    "interval_work_cycles_count",
    decode.int,
  )
  use is_autostart_enabled <- decode.field("is_autostart_enabled", decode.bool)
  decode.success(IntervalSettings(
    interval_work_ms:,
    interval_rest_ms:,
    interval_work_cycles_count:,
    is_autostart_enabled:,
  ))
}

/// Decoder for `TimerSettings` JSON.
pub fn timer_settings_decoder() -> Decoder(TimerSettings) {
  use kind <- decode.field("type", decode.string)
  case kind {
    "INFINITE" -> decode.success(InfiniteTimer)
    "SIMPLE" -> {
      use total_time_ms <- decode.field("total_time_ms", decode.int)
      decode.success(SimpleTimer(total_time_ms))
    }
    "INTERVAL" -> {
      use settings <- decode.then(interval_settings_decoder())
      decode.success(IntervalTimer(settings))
    }
    _ -> decode.failure(InfiniteTimer, "timer settings")
  }
}

fn snapshot_object_decoder() -> Decoder(#(Snapshot, BusyBarSettings)) {
  use busy_bar_settings <- decode.field("busy_bar_settings", settings_decoder())
  use kind <- decode.field("type", decode.string)
  case kind {
    "NOT_STARTED" -> decode.success(#(NotStarted, busy_bar_settings))
    "INFINITE" -> {
      use card_id <- decode.field("card_id", decode.string)
      use is_paused <- decode.field("is_paused", decode.bool)
      decode.success(#(Infinite(card_id:, is_paused:), busy_bar_settings))
    }
    "SIMPLE" -> {
      use card_id <- decode.field("card_id", decode.string)
      use time_left_ms <- decode.field("time_left_ms", decode.int)
      use is_paused <- decode.field("is_paused", decode.bool)
      decode.success(#(
        Simple(card_id:, time_left_ms:, is_paused:),
        busy_bar_settings,
      ))
    }
    "INTERVAL" -> {
      use card_id <- decode.field("card_id", decode.string)
      use current_interval <- decode.field("current_interval", decode.int)
      use current_interval_time_total_ms <- decode.field(
        "current_interval_time_total_ms",
        decode.int,
      )
      use current_interval_time_left_ms <- decode.field(
        "current_interval_time_left_ms",
        decode.int,
      )
      use is_paused <- decode.field("is_paused", decode.bool)
      use interval_settings <- decode.field(
        "interval_settings",
        interval_settings_decoder(),
      )
      decode.success(#(
        Interval(
          card_id:,
          current_interval:,
          current_interval_time_total_ms:,
          current_interval_time_left_ms:,
          is_paused:,
          interval_settings:,
        ),
        busy_bar_settings,
      ))
    }
    _ -> decode.failure(#(NotStarted, busy_bar_settings), "busy snapshot")
  }
}

/// Decoder for the `GET /busy/snapshot` response body.
pub fn snapshot_decoder() -> Decoder(BusySnapshot) {
  use inner <- decode.field("snapshot", snapshot_object_decoder())
  use snapshot_timestamp_ms <- decode.field("snapshot_timestamp_ms", decode.int)
  let #(snapshot, busy_bar_settings) = inner
  decode.success(BusySnapshot(
    snapshot:,
    busy_bar_settings:,
    snapshot_timestamp_ms:,
  ))
}

/// Decoder for the `GET /busy/profiles/{slot}` response body.
pub fn profile_decoder() -> Decoder(BusyProfile) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use sort_order <- decode.field("sort_order", decode.int)
  use timer_settings <- decode.field("timer_settings", timer_settings_decoder())
  use busy_bar_settings <- decode.field("busy_bar_settings", settings_decoder())
  use profile_timestamp_ms <- decode.field("profile_timestamp_ms", decode.int)
  decode.success(BusyProfile(
    id:,
    title:,
    sort_order:,
    timer_settings:,
    busy_bar_settings:,
    profile_timestamp_ms:,
  ))
}

/// Encode `BusyBarSettings` as the JSON the device expects.
pub fn settings_to_json(settings: BusyBarSettings) -> Json {
  json.object([
    #("theme", json.string(settings.theme)),
    #("show_work_phase_only", json.bool(settings.show_work_phase_only)),
    #("trigger_smart_home", json.bool(settings.trigger_smart_home)),
  ])
}

fn interval_settings_props(
  settings: IntervalSettings,
) -> List(#(String, Json)) {
  [
    #("interval_work_ms", json.int(settings.interval_work_ms)),
    #("interval_rest_ms", json.int(settings.interval_rest_ms)),
    #(
      "interval_work_cycles_count",
      json.int(settings.interval_work_cycles_count),
    ),
    #("is_autostart_enabled", json.bool(settings.is_autostart_enabled)),
  ]
}

/// Encode `TimerSettings` as the JSON the device expects.
pub fn timer_settings_to_json(settings: TimerSettings) -> Json {
  case settings {
    InfiniteTimer -> json.object([#("type", json.string("INFINITE"))])
    SimpleTimer(total_time_ms) ->
      json.object([
        #("type", json.string("SIMPLE")),
        #("total_time_ms", json.int(total_time_ms)),
      ])
    IntervalTimer(interval) ->
      json.object([
        #("type", json.string("INTERVAL")),
        ..interval_settings_props(interval)
      ])
  }
}

fn snapshot_props(snapshot: Snapshot) -> List(#(String, Json)) {
  case snapshot {
    NotStarted -> [#("type", json.string("NOT_STARTED"))]
    Infinite(card_id, is_paused) -> [
      #("type", json.string("INFINITE")),
      #("card_id", json.string(card_id)),
      #("is_paused", json.bool(is_paused)),
    ]
    Simple(card_id, time_left_ms, is_paused) -> [
      #("type", json.string("SIMPLE")),
      #("card_id", json.string(card_id)),
      #("time_left_ms", json.int(time_left_ms)),
      #("is_paused", json.bool(is_paused)),
    ]
    Interval(
      card_id,
      current_interval,
      current_interval_time_total_ms,
      current_interval_time_left_ms,
      is_paused,
      interval_settings,
    ) -> [
      #("type", json.string("INTERVAL")),
      #("card_id", json.string(card_id)),
      #("current_interval", json.int(current_interval)),
      #(
        "current_interval_time_total_ms",
        json.int(current_interval_time_total_ms),
      ),
      #(
        "current_interval_time_left_ms",
        json.int(current_interval_time_left_ms),
      ),
      #("is_paused", json.bool(is_paused)),
      #(
        "interval_settings",
        json.object([
          #("type", json.string("INTERVAL")),
          ..interval_settings_props(interval_settings)
        ]),
      ),
    ]
  }
}

/// Encode a `BusySnapshot` as the JSON the device expects.
pub fn snapshot_to_json(snapshot: BusySnapshot) -> Json {
  json.object([
    #(
      "snapshot",
      json.object(
        list.append(snapshot_props(snapshot.snapshot), [
          #("busy_bar_settings", settings_to_json(snapshot.busy_bar_settings)),
        ]),
      ),
    ),
    #("snapshot_timestamp_ms", json.int(snapshot.snapshot_timestamp_ms)),
  ])
}

/// Encode a `BusyProfile` as the JSON the device expects.
pub fn profile_to_json(profile: BusyProfile) -> Json {
  json.object([
    #("id", json.string(profile.id)),
    #("title", json.string(profile.title)),
    #("sort_order", json.int(profile.sort_order)),
    #("timer_settings", timer_settings_to_json(profile.timer_settings)),
    #("busy_bar_settings", settings_to_json(profile.busy_bar_settings)),
    #("profile_timestamp_ms", json.int(profile.profile_timestamp_ms)),
  ])
}

/// Build the `GET /busy/snapshot` request without sending it.
pub fn get_snapshot_request(client: Client) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/busy/snapshot")
}

/// Get the current busy-timer state as a snapshot.
pub fn get_snapshot(client: Client) -> Result(BusySnapshot, Error) {
  use req <- result.try(get_snapshot_request(client))
  api.send_json(req, snapshot_decoder())
}

/// Build the `PUT /busy/snapshot` request without sending it.
pub fn set_snapshot_request(
  client: Client,
  snapshot: BusySnapshot,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(client, http.Put, "/busy/snapshot"))
  Ok(api.with_json_body(req, snapshot_to_json(snapshot)))
}

/// Run the busy timer starting from the given snapshot.
pub fn set_snapshot(
  client: Client,
  snapshot: BusySnapshot,
) -> Result(Nil, Error) {
  use req <- result.try(set_snapshot_request(client, snapshot))
  api.send_expect_success(req)
}

/// Build the `GET /busy/profiles/{slot}` request without sending it.
pub fn get_profile_request(
  client: Client,
  slot: ProfileSlot,
) -> Result(Request(String), Error) {
  api.request_for(client, http.Get, "/busy/profiles/" <> slot_to_string(slot))
}

/// Get the timer profile stored in a slot.
pub fn get_profile(
  client: Client,
  slot: ProfileSlot,
) -> Result(BusyProfile, Error) {
  use req <- result.try(get_profile_request(client, slot))
  api.send_json(req, profile_decoder())
}

/// Build the `PUT /busy/profiles/{slot}` request without sending it.
pub fn set_profile_request(
  client: Client,
  slot: ProfileSlot,
  profile: BusyProfile,
) -> Result(Request(String), Error) {
  use req <- result.try(api.request_for(
    client,
    http.Put,
    "/busy/profiles/" <> slot_to_string(slot),
  ))
  Ok(api.with_json_body(req, profile_to_json(profile)))
}

/// Store a timer profile in a slot.
pub fn set_profile(
  client: Client,
  slot: ProfileSlot,
  profile: BusyProfile,
) -> Result(Nil, Error) {
  use req <- result.try(set_profile_request(client, slot, profile))
  api.send_expect_success(req)
}
