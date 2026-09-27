-----------------------------------------------------------------------------
-- |
-- Phase 5 of the checklist: data sources - GeoJSON\/KML\/CZML loading and
-- @viewer.dataSources@.
--
-- Every load here is genuinely asynchronous in Cesium (they fetch and
-- parse a file), so this is also where the Phase 0 "Promise bridging"
-- checklist item gets exercised: each @safe@ import below runs an
-- @await@ed JS expression, and GHC's wasm runtime suspends the calling
-- Haskell thread (not the whole runtime) until it settles.
-----------------------------------------------------------------------------
module Cesium.DataSource
  ( DataSource
  , unDataSource
  , loadGeoJsonUrl
  , loadGeoJsonData
  , loadKmlUrl
  , loadCzmlUrl
  , newCustomDataSource
  , addDataSource
  , removeDataSource
  , removeAllDataSources
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @DataSource@ (any of @GeoJsonDataSource@,
-- @KmlDataSource@, @CzmlDataSource@, @CustomDataSource@ - they share an
-- interface).
newtype DataSource = DataSource JSVal

unDataSource :: DataSource -> JSVal
unDataSource (DataSource d) = d
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.GeoJsonDataSource.load($1, $2)"
  js_loadGeoJsonUrl :: JSString -> JSVal -> IO JSVal

-- | Load GeoJSON from a URL. @opts@ is a "Cesium.Core"-built options
-- object (e.g. @{ stroke, fill, strokeWidth }@) - pass an empty 'newObject'
-- for defaults.
loadGeoJsonUrl :: String -> JSVal -> IO DataSource
loadGeoJsonUrl url opts = DataSource <$> js_loadGeoJsonUrl (str url) opts
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.GeoJsonDataSource.load($1, $2)"
  js_loadGeoJsonData :: JSVal -> JSVal -> IO JSVal

-- | Load GeoJSON from an already-built JS object (see "Cesium.Core") -
-- useful for inline\/generated GeoJSON with no URL to fetch.
loadGeoJsonData :: JSVal -> JSVal -> IO DataSource
loadGeoJsonData geojson opts = DataSource <$> js_loadGeoJsonData geojson opts
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.KmlDataSource.load($1, $2)"
  js_loadKmlUrl :: JSString -> JSVal -> IO JSVal

-- | Load KML from a URL.
loadKmlUrl :: String -> JSVal -> IO DataSource
loadKmlUrl url opts = DataSource <$> js_loadKmlUrl (str url) opts
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.CzmlDataSource.load($1)"
  js_loadCzmlUrl :: JSString -> IO JSVal

-- | Load CZML from a URL.
loadCzmlUrl :: String -> IO DataSource
loadCzmlUrl url = DataSource <$> js_loadCzmlUrl (str url)
-----------------------------------------------------------------------------
foreign import javascript unsafe "return new Cesium.CustomDataSource($1)"
  js_newCustomDataSource :: JSString -> IO JSVal

-- | An empty, named data source you populate yourself. __Note:__ adding
-- entities to it isn't bound yet - "Cesium.Entity" only knows how to add
-- to a 'Viewer' so far; same pattern, extended when something needs it.
newCustomDataSource :: String -> IO DataSource
newCustomDataSource name = DataSource <$> js_newCustomDataSource (str name)
-----------------------------------------------------------------------------
foreign import javascript safe "return await $1.dataSources.add($2)"
  js_addDataSource :: JSVal -> JSVal -> IO JSVal

-- | Add a data source to the viewer, making it visible.
addDataSource :: Viewer -> DataSource -> IO DataSource
addDataSource v (DataSource d) = DataSource <$> js_addDataSource (unViewer v) d
-----------------------------------------------------------------------------
foreign import javascript unsafe "return $1.dataSources.remove($2, true)"
  js_removeDataSource :: JSVal -> JSVal -> IO Bool

-- | Remove a data source (and destroy it).
removeDataSource :: Viewer -> DataSource -> IO Bool
removeDataSource v (DataSource d) = js_removeDataSource (unViewer v) d
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.dataSources.removeAll()"
  js_removeAllDataSources :: JSVal -> IO ()

removeAllDataSources :: Viewer -> IO ()
removeAllDataSources v = js_removeAllDataSources (unViewer v)
-----------------------------------------------------------------------------
