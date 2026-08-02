# busybar_unofficial

Unofficial [Gleam](https://gleam.run) client for the
[BUSY Bar](https://busy.app) HTTP API (Erlang target).

Wraps API spec v1.1.1 (vendored in `openapi/`). Not affiliated with Flipper
Devices / BUSY.

## Usage

```gleam
import busybar_unofficial as busybar
import busybar_unofficial/system

pub fn main() {
  let client =
    busybar.new("http://192.168.4.1")
    |> busybar.with_token("bar-scope-api-token")
  let assert Ok(status) = system.get_status(client)
}
```

## Modules

| Module | Covers |
|---|---|
| `busybar_unofficial` | Client + Error types |
| `busybar_unofficial/account` | Cloud account info, MQTT status, backend |
| `busybar_unofficial/assets` | App asset upload/delete |
| `busybar_unofficial/audio` | Playback and volume |
| `busybar_unofficial/ble` | BLE enable/disable/pairing/status |
| `busybar_unofficial/busy` | Busy timer snapshot and profiles |
| `busybar_unofficial/display` | Draw elements, clear, brightness |
| `busybar_unofficial/settings` | Input keys, HTTP access, name, transport |
| `busybar_unofficial/smart_home` | Matter pairing and emulated switch |
| `busybar_unofficial/storage` | Device file storage |
| `busybar_unofficial/system` | Status, version, screen capture, log dump |
| `busybar_unofficial/time` | Clock and timezone |
| `busybar_unofficial/updater` | Firmware updates and autoupdate |
| `busybar_unofficial/wifi` | Wi-Fi status |

Not covered: the WebSocket streaming endpoint (`/busybar/status/ws`).

## Development

```sh
just deps && just test   # unit tests, no device needed
BUSYBAR_URL=http://<device-ip> just test-integration
```
