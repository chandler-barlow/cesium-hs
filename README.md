# miso-cesium

Haskell bindings for [CesiumJS](https://cesium.com/platform/cesiumjs/),
for [Miso](https://haskell-miso.org) apps compiled with GHC's
**wasm** backend - no jsaddle, no GHCJS, just GHC's own JavaScript FFI
(`foreign import/export javascript`) targeting `wasm32-wasi`.

See [`docs/checklist.md`](docs/checklist.md) for the full feature-by-feature
status of what's bound so far.

## Prerequisites

[Nix](https://nixos.org) with flakes enabled. That's it - the flake
provides the wasm GHC toolchain, `cabal`, and the dev tooling
(`http-server`, `wasm-opt`, `ghciwatch`, ...).

## Quick start: the demo app

```sh
git clone git@github.com:chandler-barlow/cesium-hs.git
cd cesium-hs
nix develop .#wasm --command bash -c 'make && make serve'
```

Then open the URL `http-server` prints (typically `http://127.0.0.1:8080`).
You should see a globe centered over the continental US, an OSM tile
overlay, and - if the flight proxy is running (see below) - upward of a
thousand live aircraft as little icons, oriented to their heading. Click
one to log the picked entity to the browser console.

For faster iteration, `make repl` gives you a browser-connected GHCi
session instead of a full rebuild each time:

```sh
nix develop .#wasm --command make repl
```

then open `http://127.0.0.1:8080/main.html` and re-evaluate `main` after
edits.

## Live flights demo

The globe includes a live public-flights overlay, sourced from
[adsb.lol](https://adsb.lol)'s free API. adsb.lol doesn't send CORS
headers, so the browser can't fetch it directly - a small native proxy
(`adsb-proxy`) fetches server-side and re-serves it with permissive CORS.
Run it in a **second terminal**, from the project's default devShell (not
`.#wasm` - it's an ordinary native executable):

```sh
nix develop --command cabal run adsb-proxy
# or: make proxy
```

It listens on `http://localhost:8790`. With both `make serve` and the
proxy running, reload the page and aircraft across the whole US should
appear within a few seconds (typically 1000-1500 of them), refreshing
every 5s - each aircraft glides smoothly between updates (via a
`SampledPositionProperty` per aircraft) rather than popping to its new
position. Without the proxy running, the demo still works - you'll just
see a "flight poll failed" message in the browser console instead of
aircraft.

## Project layout

- `lib/Cesium/*.hs` - the bindings themselves, one module per Cesium area
  (`Viewer`, `Entity`, `DataSource`, `Imagery`, `Terrain`, `Tileset`,
  `Scene`, `Clock`, ...), plus `Core` (shared FFI primitives) and
  `Browser` (generic Web API bindings - fetch, timers).
- `lib/Cesium/Options.hs` + `lib/Cesium/Simple.hs` - a higher-level,
  more ergonomic layer: define a plain record with fields named like
  Cesium's own JS options, `deriving Generic`, and get JS-object
  conversion for free. Opt-in - import `Cesium.Simple` qualified
  alongside the raw `Cesium` module, not instead of it.
- `app/` - `cesium-hello-globe`, the demo/example Miso app (wasm).
- `proxy/` - `adsb-proxy`, the native CORS proxy for the live-flights demo.
- `docs/checklist.md` - the feature-by-feature binding checklist.

## License

MIT (bindings/example code) - see `LICENSE`. CesiumJS itself is
Apache-2.0; adsb.lol's data is provided under their own terms.
