//// Read-only smoke tests against a real BUSY Bar.
//// Set BUSYBAR_URL (and BUSYBAR_TOKEN if access mode requires it) to enable;
//// without them these tests pass as no-ops.

import busybar_unofficial
import busybar_unofficial/busy
import busybar_unofficial/settings
import busybar_unofficial/system
import envoy
import gleam/io

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
