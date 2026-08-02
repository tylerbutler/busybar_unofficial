# busybar_unofficial tasks

alias b := build
alias t := test
alias f := format
alias c := check

default:
    @just --list

deps:
    gleam deps download

build:
    gleam build

build-strict:
    gleam build --warnings-as-errors

test:
    gleam test

# Run tests including the device integration suite (requires a BUSY Bar on the network)
test-integration:
    @test -n "${BUSYBAR_URL:-}" || (echo "Set BUSYBAR_URL (and optionally BUSYBAR_TOKEN) first" && exit 1)
    gleam test

format:
    gleam format src test

format-check:
    gleam format --check src test

check:
    gleam check

docs:
    gleam docs build

clean:
    rm -rf build

ci: format-check check test build-strict
