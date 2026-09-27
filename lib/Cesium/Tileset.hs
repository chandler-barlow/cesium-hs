-----------------------------------------------------------------------------
-- |
-- Phase 8 of the checklist: 3D Tiles.
--
-- __Not yet exercised from the example__ - both construction paths need
-- something we don't have on hand: 'tilesetFromIonAssetId' needs a real
-- Ion token (see "Cesium.Core"'s @setIonAccessToken@), and
-- 'tilesetFromUrl' needs a hosted @tileset.json@. Same pattern as the
-- other Ion-gated Phase 6 bindings - implemented and type-checked, just
-- not proven against a real endpoint yet.
-----------------------------------------------------------------------------
module Cesium.Tileset
  ( Tileset
  , tilesetFromUrl
  , tilesetFromIonAssetId
  , addTilesetToScene
  , TilesetStyle
  , newTilesetStyle
  , setTilesetStyle
  , onAllTilesLoaded
  , onTileLoad
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @Cesium3DTileset@ instance.
newtype Tileset = Tileset JSVal
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.Cesium3DTileset.fromUrl($1, $2)"
  js_tilesetFromUrl :: JSString -> JSVal -> IO JSVal

-- | Load a tileset from a hosted @tileset.json@ URL.
tilesetFromUrl :: String -> JSVal -> IO Tileset
tilesetFromUrl url opts = Tileset <$> js_tilesetFromUrl (str url) opts
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.Cesium3DTileset.fromIonAssetId($1, $2)"
  js_tilesetFromIonAssetId :: Double -> JSVal -> IO JSVal

-- | Load a tileset from a Cesium Ion asset id. Requires
-- 'Cesium.Core.setIonAccessToken' to have been called with a valid token
-- first.
tilesetFromIonAssetId :: Double -> JSVal -> IO Tileset
tilesetFromIonAssetId assetId opts = Tileset <$> js_tilesetFromIonAssetId assetId opts
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.scene.primitives.add($2)"
  js_addTilesetToScene :: JSVal -> JSVal -> IO ()

addTilesetToScene :: Viewer -> Tileset -> IO ()
addTilesetToScene v (Tileset t) = js_addTilesetToScene (unViewer v) t
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @Cesium3DTileStyle@ instance.
newtype TilesetStyle = TilesetStyle JSVal

foreign import javascript unsafe "return new Cesium.Cesium3DTileStyle($1)"
  js_newTilesetStyle :: JSVal -> IO JSVal

-- | @opts@ (built with "Cesium.Core") is the style JSON, e.g.
-- @{ color: \"color('red')\" }@.
newTilesetStyle :: JSVal -> IO TilesetStyle
newTilesetStyle opts = TilesetStyle <$> js_newTilesetStyle opts

foreign import javascript unsafe "$1.style = $2"
  js_setTilesetStyle :: JSVal -> JSVal -> IO ()

setTilesetStyle :: Tileset -> TilesetStyle -> IO ()
setTilesetStyle (Tileset t) (TilesetStyle s) = js_setTilesetStyle t s
-----------------------------------------------------------------------------
foreign import javascript "wrapper"
  js_wrapNullaryCallback :: IO () -> IO JSVal

foreign import javascript unsafe "$1.allTilesLoaded.addEventListener($2)"
  js_onAllTilesLoaded :: JSVal -> JSVal -> IO ()

onAllTilesLoaded :: Tileset -> IO () -> IO ()
onAllTilesLoaded (Tileset t) cb = do
  cbVal <- js_wrapNullaryCallback cb
  js_onAllTilesLoaded t cbVal
-----------------------------------------------------------------------------
foreign import javascript "wrapper"
  js_wrapTileCallback :: (JSVal -> IO ()) -> IO JSVal

foreign import javascript unsafe "$1.tileLoad.addEventListener($2)"
  js_onTileLoad :: JSVal -> JSVal -> IO ()

-- | The 'JSVal' passed to the callback is the loaded @Cesium3DTile@.
onTileLoad :: Tileset -> (JSVal -> IO ()) -> IO ()
onTileLoad (Tileset t) cb = do
  cbVal <- js_wrapTileCallback cb
  js_onTileLoad t cbVal
-----------------------------------------------------------------------------
