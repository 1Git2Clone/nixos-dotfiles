# Rust build flags live in ~/.cargo/config.toml. Don't export RUSTFLAGS here: Cargo then ignores
# the config's rustflags (mold was never used), and an -C opt-level in it overrides every profile's.
