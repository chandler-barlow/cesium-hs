-----------------------------------------------------------------------------
-- |
-- Phase 6 of the checklist (imagery half): imagery providers and
-- @viewer.imageryLayers@.
-----------------------------------------------------------------------------
module Cesium.Imagery
  ( ImageryProvider
  , urlTemplateImageryProvider
  , webMapServiceImageryProvider
  , ionImageryProviderFromAssetId
  , ImageryLayer
  , addImageryLayer
  , removeImageryLayer
  , setImageryLayerAlpha
  , setImageryLayerBrightness
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS imagery provider (@UrlTemplateImageryProvider@,
-- @WebMapServiceImageryProvider@, @IonImageryProvider@, ...).
newtype ImageryProvider = ImageryProvider JSVal
-----------------------------------------------------------------------------
foreign import javascript unsafe "return new Cesium.UrlTemplateImageryProvider($1)"
  js_urlTemplateImageryProvider :: JSVal -> IO JSVal

-- | @opts@ (built with "Cesium.Core") must at least set @url@, e.g.
-- @\"https:\/\/tile.openstreetmap.org\/{z}\/{x}\/{y}.png\"@.
urlTemplateImageryProvider :: JSVal -> IO ImageryProvider
urlTemplateImageryProvider opts = ImageryProvider <$> js_urlTemplateImageryProvider opts
-----------------------------------------------------------------------------
foreign import javascript unsafe "return new Cesium.WebMapServiceImageryProvider($1)"
  js_webMapServiceImageryProvider :: JSVal -> IO JSVal

-- | @opts@ must at least set @url@ and @layers@.
webMapServiceImageryProvider :: JSVal -> IO ImageryProvider
webMapServiceImageryProvider opts = ImageryProvider <$> js_webMapServiceImageryProvider opts
-----------------------------------------------------------------------------
foreign import javascript safe "return await Cesium.IonImageryProvider.fromAssetId($1, $2)"
  js_ionImageryProviderFromAssetId :: Double -> JSVal -> IO JSVal

-- | Requires 'Cesium.Core.setIonAccessToken' to have been called with a
-- valid token first.
ionImageryProviderFromAssetId :: Double -> JSVal -> IO ImageryProvider
ionImageryProviderFromAssetId assetId opts =
  ImageryProvider <$> js_ionImageryProviderFromAssetId assetId opts
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @ImageryLayer@ - a provider attached to a
-- viewer, with its own alpha\/brightness\/etc.
newtype ImageryLayer = ImageryLayer JSVal
-----------------------------------------------------------------------------
foreign import javascript unsafe "return $1.imageryLayers.addImageryProvider($2)"
  js_addImageryLayer :: JSVal -> JSVal -> IO JSVal

-- | Add a provider as a new top layer.
addImageryLayer :: Viewer -> ImageryProvider -> IO ImageryLayer
addImageryLayer v (ImageryProvider p) = ImageryLayer <$> js_addImageryLayer (unViewer v) p
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.imageryLayers.remove($2, true)"
  js_removeImageryLayer :: JSVal -> JSVal -> IO ()

removeImageryLayer :: Viewer -> ImageryLayer -> IO ()
removeImageryLayer v (ImageryLayer l) = js_removeImageryLayer (unViewer v) l
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.alpha = $2"
  js_setImageryLayerAlpha :: JSVal -> Double -> IO ()

-- | @0@ (invisible) to @1@ (opaque).
setImageryLayerAlpha :: ImageryLayer -> Double -> IO ()
setImageryLayerAlpha (ImageryLayer l) = js_setImageryLayerAlpha l
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.brightness = $2"
  js_setImageryLayerBrightness :: JSVal -> Double -> IO ()

-- | @1@ is normal; @< 1@ darkens, @> 1@ brightens.
setImageryLayerBrightness :: ImageryLayer -> Double -> IO ()
setImageryLayerBrightness (ImageryLayer l) = js_setImageryLayerBrightness l
-----------------------------------------------------------------------------
