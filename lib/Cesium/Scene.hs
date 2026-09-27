-----------------------------------------------------------------------------
-- |
-- Phase 9 of the checklist (scene\/globe half): the handful of
-- @viewer.scene@\/@viewer.scene.globe@ toggles that are easy wins - not an
-- attempt at the full @Scene@\/@Globe@ surface.
-----------------------------------------------------------------------------
module Cesium.Scene
  ( setFogEnabled
  , setSkyAtmosphereShow
  , setMsaaSamples
  , setGlobeBaseColor
  , setDepthTestAgainstTerrain
  , setGlobeTranslucency
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Math (Color, unColor)
import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.scene.fog.enabled = $2"
  js_setFogEnabled :: JSVal -> Bool -> IO ()

setFogEnabled :: Viewer -> Bool -> IO ()
setFogEnabled v = js_setFogEnabled (unViewer v)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.scene.skyAtmosphere.show = $2"
  js_setSkyAtmosphereShow :: JSVal -> Bool -> IO ()

setSkyAtmosphereShow :: Viewer -> Bool -> IO ()
setSkyAtmosphereShow v = js_setSkyAtmosphereShow (unViewer v)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.scene.msaaSamples = $2"
  js_setMsaaSamples :: JSVal -> Double -> IO ()

-- | Anti-aliasing sample count, e.g. @1@ (off), @4@, @8@.
setMsaaSamples :: Viewer -> Double -> IO ()
setMsaaSamples v = js_setMsaaSamples (unViewer v)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.scene.globe.baseColor = $2"
  js_setGlobeBaseColor :: JSVal -> JSVal -> IO ()

-- | Color shown where no imagery is loaded (e.g. gaps, or below imagery
-- with alpha < 1).
setGlobeBaseColor :: Viewer -> Color -> IO ()
setGlobeBaseColor v c = js_setGlobeBaseColor (unViewer v) (unColor c)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.scene.globe.depthTestAgainstTerrain = $2"
  js_setDepthTestAgainstTerrain :: JSVal -> Bool -> IO ()

-- | When 'True', entities\/primitives behind terrain are correctly
-- occluded rather than always drawn on top.
setDepthTestAgainstTerrain :: Viewer -> Bool -> IO ()
setDepthTestAgainstTerrain v = js_setDepthTestAgainstTerrain (unViewer v)
-----------------------------------------------------------------------------
foreign import javascript unsafe
  "$1.scene.globe.translucency.enabled = $2; $1.scene.globe.translucency.frontFaceAlpha = $3"
  js_setGlobeTranslucency :: JSVal -> Bool -> Double -> IO ()

-- | @setGlobeTranslucency viewer enabled frontFaceAlpha@ - see through the
-- globe (e.g. to inspect terrain-hugging entities from below).
setGlobeTranslucency :: Viewer -> Bool -> Double -> IO ()
setGlobeTranslucency v enabled alpha = js_setGlobeTranslucency (unViewer v) enabled alpha
-----------------------------------------------------------------------------
