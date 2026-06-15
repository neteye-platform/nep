# Nep

To compile the nep executable you should install Rust first:
```shell
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
Then install the musl toolchain for compiling a static binary:
```shell
rustup target add x86_64-unknown-linux-musl
```
Then just run:
```shell
cargo build --release --target=x86_64-unknown-linux-musl
```
The result executable will be in `./target/x86_64-unknown-linux-musl/release/nep`.

### Compilation notes
The resulting file is big because everything is statically compiled so it has no
requirement and it can be used to install anything in any situation.
To speed up the compilation, in `Cargo.toml` comment the line `codegen-units=1`, at the cost of a slight performance degradation.
To reduce the size of the compiled binary refer to https://github.com/johnthagen/min-sized-rust

### In Docker / Podman:
```
podman -it -v"$PWD:/io" rust:latest bash
apt update
apt install musl-tools
rustup target add x86_64-unknown-linux-musl
cd /io/setup
cargo build --release --target=x86_64-unknown-linux-musl
```