
.PHONY= update build optim

all: update build optim

update:
	wasm32-wasi-cabal update

build:
	wasm32-wasi-cabal build
	rm -rf public
	cp -r static public
	$(eval my_wasm=$(shell wasm32-wasi-cabal list-bin cesium-hello-globe | tail -n 1))
	$(shell wasm32-wasi-ghc --print-libdir)/post-link.mjs --input $(my_wasm) --output public/ghc_wasm_jsffi.js
	cp -v $(my_wasm) public/app.wasm

optim:
	wasm-opt -all -O2 public/app.wasm -o public/app.wasm
	wasm-tools strip -o public/app.wasm public/app.wasm

repl:
	wasm32-wasi-cabal repl cesium-hello-globe -finteractive --repl-options='-fghci-browser -fghci-browser-port=8080'

serve:
	http-server public

# For the live-flights demo. Native, not wasm - run this from the
# project's *default* devShell (`nix develop`, no `.#wasm`), in its own
# terminal, alongside `make serve`. See proxy/Main.hs.
proxy:
	cabal run adsb-proxy

clean:
	rm -rf dist-newstyle public
