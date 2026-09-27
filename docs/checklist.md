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
- [ ] Callback bridging (`"wrapper"` dynamic exports) for JS → Haskell event callbacks
- [ ] Promise bridging proven for an async Cesium call (`safe` import + `await` in the JS snippet)
- [ ] Cleanup on component unmount (`destroyViewer` actually wired to `unmount`)
- [ ] JS exception → Haskell error handling story at the FFI boundary

## Phase 1 - MVP: hello globe

- [x] `Cesium.Viewer`: `newViewer`, `destroyViewer`
- [x] `Cesium.Viewer`: `flyTo`
- [ ] Verified end-to-end in a real browser (not yet run - first thing to check with `make repl`)

## Phase 2 - Core math types

- [ ] `Cartesian2`, `Cartesian3`, `Cartesian4`
- [ ] `Cartographic` + `fromDegrees`/`fromRadians`
- [ ] `Color` (named colors + `fromCssColorString`)
- [ ] `Matrix3`, `Matrix4`, `Quaternion`, `Transforms`
- [ ] `Rectangle`
- [ ] `JulianDate`

## Phase 3 - Camera & interaction

- [ ] `Camera`: `position`, heading/pitch/roll, `flyToBoundingSphere`, `lookAt`, `setView`
- [ ] `ScreenSpaceEventHandler` + `ScreenSpaceEventType` (click/mousemove/wheel) → Haskell callbacks
- [ ] `ScreenSpaceCameraController` options (enable/disable rotate/zoom/tilt)

## Phase 4 - Entity API

- [ ] `Entity` + `EntityCollection` (`viewer.entities.add`/`remove`)
- [ ] `PointGraphics`, `LabelGraphics`, `BillboardGraphics`
- [ ] `PolylineGraphics`, `PolygonGraphics`, `RectangleGraphics`, `EllipseGraphics`
- [ ] `ModelGraphics` (glTF models)
- [ ] Entity picking (`viewer.scene.pick`) wired back through the click callback

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
