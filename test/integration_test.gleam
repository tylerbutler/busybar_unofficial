//// Smoke tests against a real BUSY Bar.
//// Set BUSYBAR_URL (and BUSYBAR_TOKEN if access mode requires it) to enable;
//// without them these tests pass as no-ops.
////
//// Everything here is read-only except the logo test, which takes over the
//// screen — that one needs BUSYBAR_DRAW=1 as well, so BUSYBAR_URL on its own
//// never changes what the device is showing.

import busybar_unofficial
import busybar_unofficial/busy
import busybar_unofficial/display
import busybar_unofficial/settings
import busybar_unofficial/system
import envoy
import gleam/io
import gleam/option.{None, Some}
import simplifile

fn device_client() -> Result(busybar_unofficial.Client, Nil) {
  case envoy.get("BUSYBAR_URL") {
    Error(Nil) -> Error(Nil)
    Ok(url) -> {
      let client = busybar_unofficial.new(url)
      case envoy.get("BUSYBAR_TOKEN") {
        Ok(token) -> Ok(busybar_unofficial.with_token(client, token))
        Error(Nil) -> Ok(client)
      }
    }
  }
}

pub fn device_version_integration_test() {
  case device_client() {
    Error(Nil) -> io.println("BUSYBAR_URL not set; skipping integration test")
    Ok(client) -> {
      let assert Ok(_version) = system.get_version(client)
      Nil
    }
  }
}

pub fn device_status_integration_test() {
  case device_client() {
    Error(Nil) -> Nil
    Ok(client) -> {
      let assert Ok(_status) = system.get_status(client)
      let assert Ok(_power) = system.get_power_status(client)
      Nil
    }
  }
}

pub fn device_name_integration_test() {
  case device_client() {
    Error(Nil) -> Nil
    Ok(client) -> {
      let assert Ok(_name) = settings.get_name(client)
      Nil
    }
  }
}

pub fn device_busy_snapshot_integration_test() {
  case device_client() {
    Error(Nil) -> Nil
    Ok(client) -> {
      let assert Ok(_snapshot) = busy.get_snapshot(client)
      Nil
    }
  }
}

/// Only returns a client when the caller has opted in to writing to the
/// screen, on top of the usual BUSYBAR_URL gate.
fn draw_client() -> Result(busybar_unofficial.Client, Nil) {
  case envoy.get("BUSYBAR_DRAW") {
    Ok("1") -> device_client()
    _ -> Error(Nil)
  }
}

pub fn device_draw_gleam_logo_integration_test() {
  case draw_client() {
    Error(Nil) -> Nil
    Ok(client) -> {
      let assert Ok(logo) = simplifile.read_bits("priv/gleam_logo_72x16.png")
      // priority 90 to draw over an active BUSY session; the 10s timeout
      // hands the screen back on its own, so there is nothing to clean up.
      let element =
        display.Image(
          base: display.ElementBase(
            id: "lucy",
            timeout: Some(10),
            display_until: None,
            x: None,
            y: None,
            display: Some(display.Front),
            align: Some(display.TopLeft),
          ),
          source: display.AppAsset("gleam.png"),
          opacity: None,
        )
      let assert Ok(Nil) =
        display.upload_and_draw(
          client,
          "gleam.png",
          logo,
          display.DrawRequest(
            application_name: "gleam_logo",
            priority: Some(90),
            led_notification_color: None,
            elements: [element],
          ),
        )
      Nil
    }
  }
}
