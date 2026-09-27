# CesiumJS binding checklist

Feature-by-feature tracker for the Miso/wasm bindings to CesiumJS. Package
layout: `Cesium.*` modules under `lib/`, raw FFI over `GHC.Wasm.Prim`
(`GHC.Wasm.Prim`/`JSVal`/`JSString`), no jsaddle, GHC wasm backend only.

Check an item off once its binding compiles *and* has been exercised from
`cesium-hello-globe` (or the ghci-browser REPL) in a real browser - a
type-checked FFI import that's never been called is not verified.

## Phase 0 - FFI plumbing

- [x] `Cesium.Core`: `newObject`/`setProp*`/`getProp`/`global` helpers over `JSVal`
- [x] Div-mounting escape hatch (`viewModel` renders a stable childless div; Cesium owns its subtree)
- [x] Callback bridging (`"wrapper"` dynamic exports) for JS → Haskell event callbacks - `Cesium.Events.onLeftClick`
- [ ] Wire a Cesium-originated callback back into a Miso component's own `Action`/update loop (`withSink`/`issue`) - currently callbacks just run plain `IO` directly (see `Cesium.Events`)
- [ ] Promise bridging proven for an async Cesium call (`safe` import + `await` in the JS snippet)
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

- [ ] `GeoJsonDataSource.load`
- [ ] `KmlDataSource.load`
- [ ] `CzmlDataSource.load`
- [ ] `CustomDataSource`
- [ ] `DataSourceCollection` (`viewer.dataSources`)

## Phase 6 - Imagery & terrain

- [ ] `ImageryLayerCollection`/`ImageryLayer` (add/remove/reorder, alpha/brightness)
- [ ] `UrlTemplateImageryProvider`, `WebMapServiceImageryProvider`, `IonImageryProvider`
- [ ] `TerrainProvider` interface, `CesiumTerrainProvider`, `EllipsoidTerrainProvider`
- [ ] `Cesium.Ion.defaultAccessToken` configuration

## Phase 7 - Primitives (stretch)

- [ ] `PrimitiveCollection`, `Primitive`, `GroundPrimitive`
- [ ] `PointPrimitiveCollection`, `BillboardCollection`, `LabelCollection`
- [ ] `Appearance`/`Material` subset

## Phase 8 - 3D Tiles

- [ ] `Cesium3DTileset.fromUrl`/`fromIonAssetId`
- [ ] `Cesium3DTileStyle`
- [ ] Tileset events (`tileLoad`, `allTilesLoaded`)

## Phase 9 - Scene/Globe/Clock

- [ ] `Scene` options (fog, skybox, sky atmosphere, MSAA)
- [ ] `Globe` (base color, depth-test-against-terrain, translucency)
- [ ] `Clock` + `ClockRange` + `TimeIntervalCollection`

## Cross-cutting, ongoing

- [ ] Cesium version pinned and tracked explicitly (currently 1.145.0 via jsdelivr in `static/index.html`)
- [ ] An example app per phase, manually checked in a real browser
- [ ] Idiomatic wrapper layer (Haskell records/ADTs over the raw options-object builder) - decide per-binding, not up front
