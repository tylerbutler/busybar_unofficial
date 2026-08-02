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

## Development

```sh
just deps && just test   # unit tests, no device needed
BUSYBAR_URL=http://<device-ip> just test-integration
```
