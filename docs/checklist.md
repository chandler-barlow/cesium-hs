# CesiumJS binding checklist

Feature-by-feature tracker for the Miso/wasm bindings to CesiumJS. Package
layout: `Cesium.*` modules under `lib/`, raw FFI over `GHC.Wasm.Prim`
(`GHC.Wasm.Prim`/`JSVal`/`JSString`), no jsaddle, GHC wasm backend only.

Check an item off once its binding compiles *and* has been exercised from
`cesium-hello-globe` (or the ghci-browser REPL) in a real browser - a
type-checked FFI import that's never been called is not verified.

## Higher-level layer: Cesium.Simple

Everything above is intentionally raw: options objects are built by hand
with `Cesium.Core`'s `newObject`/`setProp*`, and each convenience
constructor only exposes the handful of fields it was written for.
`Cesium.Options` adds a generic `ToOptions` typeclass (`GHC.Generics`-
derived): define a record with fields named exactly like Cesium's own JS
option keys, wrap each in `Maybe` (`Nothing` = omit the key, Cesium's
default applies), derive `Generic`, write an empty `instance ToOptions
MyRecord` - done. `Cesium.Simple` is the first consumer of that machinery:

- [x] `ViewerOptions` (the boolean UI-widget toggles) + `newViewer`
- [x] `PointOptions` (`pixelSize`/`color`/`outlineColor`/`outlineWidth`/`show`) + `addPointEntity`
- [x] `LabelOptions` (`text`/`font`/`fillColor`/`outlineColor`/`showBackground`/`scale`) + `addLabelEntity`
- [ ] Everything else - same pattern (record + `deriving Generic` + empty instance + a `defaultXOptions` value), added as something needs it

Deliberately **not** re-exported from the `Cesium` umbrella module - import
it qualified (`import qualified Cesium.Simple as Simple`) since some names
(`newViewer`, field names like `color`) are meant to replace the raw ones
at a call site. Field names that collide with `Prelude` (`show`, and
eventually `id`) work because the records use `NoFieldSelectors` +
`DuplicateRecordFields` - importing modules need `DuplicateRecordFields`
too, to disambiguate same-named fields across different option records in
record-update syntax (see `app/Main.hs`).

## Demo: live public flights

`cesium-hello-globe` shows live aircraft near NYC, as a stress test of the
library (hundreds of entities, refreshed on a timer, real external JSON).

- [x] `Cesium.Browser`: `fetchJson` (async `fetch` + `JSON.parse`, in one
      JSFFI call) and `setInterval` (polling) - both generic Web API
      bindings, not Cesium-specific, but needed to pull this off
- [x] `Cesium.Core`: `arrayLength`/`arrayIndex` (walk a JS array from
      Haskell) and `hasNumProp`/`getPropNumOr`/`getPropStrOr` (read a
      field defensively - external JSON's shape isn't guaranteed the way
      Cesium's own API objects are; adsb.lol's `alt_baro` is sometimes the
      *string* `"ground"` instead of a number, which is exactly the kind
      of thing these guard against)
- [x] `app/Flights.hs`: polls every 15s, clears and rebuilds the entity
      set each time (no position smoothing/diffing yet - a small pop each
      refresh, not a smooth glide)

**Why there's a proxy at all**: the free ADS-B aggregators (adsb.lol,
airplanes.live, adsb.one, OpenSky) are built for server-side consumption,
not browser embedding - none of them send permissive CORS headers, so a
direct `fetch` from the page is blocked by the browser regardless of the
data being genuinely free and public. `proxy/Main.hs` is a small **native**
(non-wasm) executable, `adsb-proxy`, that fetches api.adsb.lol server-side
(not subject to CORS) and re-serves the JSON with
`Access-Control-Allow-Origin: *`. It needs the project's *default* devShell
(`nix develop`, not `.#wasm`) - confirmed that devShell can build a normal
native Haskell executable (same as verified for miso-bulma previously),
plus the project's own `flake.nix` now layers `pkgs.zlib` onto it
(`http-client`/`warp`'s dependency chain needs the system `libz`, which
isn't in the upstream devShell by default).

Run it with `make proxy` (or `nix develop --command cabal run adsb-proxy`)
in its own terminal, alongside `make serve`. Verified end-to-end: a real
request against a locally-running proxy returned 320 real aircraft near
NYC with the correct CORS header, and the proxy survived the request
without crashing (an earlier attempt crashed on first request - Warp's
timer manager needs `-threaded`, now in `adsb-proxy`'s `ghc-options`).

## Phase 0 - FFI plumbing

- [x] `Cesium.Core`: `newObject`/`setProp*`/`getProp`/`global` helpers over `JSVal`
- [x] Div-mounting escape hatch (`viewModel` renders a stable childless div; Cesium owns its subtree)
- [x] Callback bridging (`"wrapper"` dynamic exports) for JS → Haskell event callbacks - `Cesium.Events.onLeftClick`
- [ ] Wire a Cesium-originated callback back into a Miso component's own `Action`/update loop (`withSink`/`issue`) - currently callbacks just run plain `IO` directly (see `Cesium.Events`)
- [x] Promise bridging proven for an async Cesium call (`safe` import + `await` in the JS snippet) - `Cesium.DataSource.loadGeoJsonData`/`addDataSource`, exercised
- [ ] Cleanup on component unmount (`destroyViewer` actually wired to `unmount`)
- [ ] JS exception → Haskell error handling story at the FFI boundary

## Phase 1 - MVP: hello globe

- [x] `Cesium.Viewer`: `newViewer`, `destroyViewer`
- [x] `Cesium.Viewer`: `flyTo`
- [ ] Verified end-to-end in a real browser (not yet run - first thing to check with `make repl`)

## Phase 2 - Core math types

- [x] `Cartesian3` (`fromDegrees`/`fromRadians`) - exercised via `flyTo`/`setView`
- [ ] `Cartesian2`, `Cartesian4` - skipped for now, not yet needed by anything above
- [x] `Cartographic` (`fromDegrees`/`fromRadians`) - implemented, not yet exercised
- [x] `Color` (`fromCssColorString`, named colors) - exercised via `setBackgroundColor`
- [x] `Rectangle` (`fromDegrees`) - implemented, not yet exercised
- [ ] `Matrix3` - skipped, rarely constructed directly by user code; revisit if a future phase needs it
- [x] `Matrix4` (`IDENTITY` only) - implemented, not yet exercised
- [x] `Quaternion` (`fromAxisAngle`) - implemented, not yet exercised
- [x] `JulianDate` (`now`) - implemented, not yet exercised
- [ ] `Transforms` namespace - not started

## Phase 3 - Camera & interaction

- [x] `Camera`: `setView` (position + heading/pitch/roll) - exercised on load
- [x] `Camera`: `flyTo` (Phase 1, since refactored to take a `Cartesian3`) - exercised on click
- [ ] `Camera`: `flyToBoundingSphere`, `lookAt`, `position` getter
- [x] `ScreenSpaceEventHandler` + `LEFT_CLICK` → Haskell callback - `Cesium.Events.onLeftClick`, exercised (flies to London, logs the raw event)
- [ ] Remaining `ScreenSpaceEventType`s (mousemove, wheel, right-click, double-click)
- [ ] `ScreenSpaceCameraController` options (enable/disable rotate/zoom/tilt)

## Phase 4 - Entity API

- [x] `Entity` + `EntityCollection` (`addEntity`/`removeEntity`/`removeAllEntities`)
- [x] `PointGraphics` (`addPointEntity`) - exercised (London marker)
- [x] `LabelGraphics` (`addLabelEntity`) - exercised (London marker)
- [x] `BillboardGraphics` (`addBillboardEntity`) - implemented, not yet exercised
- [x] `PolylineGraphics` (`addPolylineEntity`) - implemented, not yet exercised
- [x] `PolygonGraphics` (`addPolygonEntity`) - implemented, not yet exercised
- [ ] `RectangleGraphics`, `EllipseGraphics` - skipped for now, same pattern as the above when needed
- [ ] `ModelGraphics` (glTF models) - skipped for now
- [x] Entity picking (`viewer.scene.pick`, `Cesium.Viewer.pick`) - exercised in the click callback (logs the picked object, if any)

## Phase 5 - Data sources

- [x] `GeoJsonDataSource.load` (`loadGeoJsonUrl`, `loadGeoJsonData`) - `loadGeoJsonData` exercised (inline Paris point, no network fetch)
- [x] `KmlDataSource.load` (`loadKmlUrl`) - implemented, not yet exercised
- [x] `CzmlDataSource.load` (`loadCzmlUrl`) - implemented, not yet exercised
- [x] `CustomDataSource` (`newCustomDataSource`) - construction only; adding entities to it isn't wired up yet (see note in `Cesium.DataSource`)
- [x] `DataSourceCollection` (`addDataSource`/`removeDataSource`/`removeAllDataSources`) - `addDataSource` exercised

## Phase 6 - Imagery & terrain

- [x] `ImageryLayerCollection`/`ImageryLayer` (`addImageryLayer`/`removeImageryLayer`, `setImageryLayerAlpha`/`Brightness`) - exercised (OSM overlay at alpha 0.5); reordering not bound yet
- [x] `UrlTemplateImageryProvider` - exercised (OSM tiles)
- [x] `WebMapServiceImageryProvider` - implemented, not yet exercised
- [x] `IonImageryProvider` (`fromAssetId`) - implemented, not yet exercised (needs a real Ion token)
- [x] `TerrainProvider` interface, `EllipsoidTerrainProvider` - exercised (`setTerrainProvider`)
- [x] `CesiumTerrainProvider.fromUrl` - implemented, not yet exercised (needs a real tileset URL/Ion token)
- [x] `Cesium.Ion.defaultAccessToken` configuration (`Cesium.Core.setIonAccessToken`) - implemented, not yet exercised (no token on hand)

## Phase 7 - Primitives (stretch)

- [ ] **Deliberately deprioritized.** The Entity API (Phase 4) already covers
      point/label/billboard/polyline/polygon for anything this spike or a
      typical app needs; raw `PrimitiveCollection`/`Primitive`/
      `GroundPrimitive`/`PointPrimitiveCollection`/`BillboardCollection`/
      `LabelCollection`/`Appearance`/`Material` is a lower-level,
      performance-tuned API (bulk-rendering thousands of primitives faster
      than the Entity API can). Worth doing only if something downstream
      actually needs that performance - revisit then.

## Phase 8 - 3D Tiles

- [x] `Cesium3DTileset.fromUrl`/`fromIonAssetId` - implemented, not yet exercised (needs a hosted tileset.json or a real Ion token)
- [x] `Cesium3DTileStyle` (`newTilesetStyle`/`setTilesetStyle`) - implemented, not yet exercised
- [x] Tileset events (`onTileLoad`, `onAllTilesLoaded`) - implemented, not yet exercised

## Phase 9 - Scene/Globe/Clock

- [x] `Scene` options: fog (`setFogEnabled`), sky atmosphere (`setSkyAtmosphereShow`), MSAA (`setMsaaSamples`) - all exercised; skybox `show` not bound (same pattern, low priority)
- [x] `Globe`: base color, depth-test-against-terrain, translucency - all exercised (`configureSceneAndClock` in the example)
- [x] `Clock`: `shouldAnimate`, `multiplier`, `clockRange`, `currentTime` - all exercised
- [ ] `TimeIntervalCollection` - not started, nothing needs it yet

## Cross-cutting, ongoing

- [ ] Cesium version pinned and tracked explicitly (currently 1.145.0 via jsdelivr in `static/index.html`)
- [ ] An example app per phase, manually checked in a real browser
- [ ] Idiomatic wrapper layer (Haskell records/ADTs over the raw options-object builder) - decide per-binding, not up front
