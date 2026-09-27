-----------------------------------------------------------------------------
-- |
-- Phase 6 of the checklist (terrain half): terrain providers and
-- @viewer.terrainProvider@.
-----------------------------------------------------------------------------
module Cesium.Terrain
  ( TerrainProvider
  , ellipsoidTerrainProvider
  , cesiumTerrainProviderFromUrl
  , setTerrainProvider
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @TerrainProvider@.
newtype TerrainProvider = TerrainProvider JSVal
-----------------------------------------------------------------------------
foreign import javascript unsafe "return new Cesium.EllipsoidTerrainProvider()"
  js_ellipsoidTerrainProvider :: IO JSVal

-- | A smooth, procedural ellipsoid - no network fetch, no elevation data.
-- Useful as a always-available fallback\/default.
ellipsoidTerrainProvider :: IO TerrainProvider
ellipsoidTerrainProvider = TerrainProvider <$> js_ellipsoidTerrainProvider
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.CesiumTerrainProvider.fromUrl($1, $2)"
  js_cesiumTerrainProviderFromUrl :: JSString -> JSVal -> IO JSVal

-- | Real elevation data from a quantized-mesh terrain tileset (e.g. a
-- Cesium Ion asset URL, or your own hosted tileset).
cesiumTerrainProviderFromUrl :: String -> JSVal -> IO TerrainProvider
cesiumTerrainProviderFromUrl url opts =
  TerrainProvider <$> js_cesiumTerrainProviderFromUrl (str url) opts
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.terrainProvider = $2"
  js_setTerrainProvider :: JSVal -> JSVal -> IO ()

setTerrainProvider :: Viewer -> TerrainProvider -> IO ()
setTerrainProvider v (TerrainProvider p) = js_setTerrainProvider (unViewer v) p
-----------------------------------------------------------------------------
