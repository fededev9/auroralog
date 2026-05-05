setup:
	mix deps.get

test:
	mix test

lint:
	mix format --check-formatted

run:
	mix phx.server

bench:
	cargo bench --manifest-path native/auralog_core/Cargo.toml
