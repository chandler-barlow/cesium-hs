-----------------------------------------------------------------------------
-- |
-- Bindings for @Cesium.Viewer@ - mounting the globe, moving the camera
-- (Phase 1 + Phase 3 of the checklist). See "Cesium.Events" for input
-- handling and @docs\/checklist.md@ for the fuller feature checklist.
-----------------------------------------------------------------------------
module Cesium.Viewer
  ( Viewer
  , unViewer
  , newViewer
  , destroyViewer
  , setBackgroundColor
  , flyTo
  , setView
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
import Cesium.Math (Cartesian3, Color, unCartesian3, unColor)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @Cesium.Viewer@ instance.
newtype Viewer = Viewer JSVal

-- | Escape hatch for other "Cesium.*" modules (e.g. "Cesium.Events") that
-- need the underlying viewer object for a raw FFI import.
unViewer :: Viewer -> JSVal
unViewer (Viewer v) = v
-----------------------------------------------------------------------------
foreign import javascript unsafe
  "return new Cesium.Viewer(document.getElementById($1), $2)"
  js_newViewer :: JSString -> JSVal -> IO JSVal

-- | Construct a viewer mounted into the element with the given id.
--
-- The options object is built with 'newObject'\/'setProp*' from
-- "Cesium.Core" rather than a Haskell record - Cesium's @Viewer@
-- constructor takes dozens of mostly-independent optional fields, and
-- modelling every combination isn't worth it this early in the spike.
newViewer :: JSString -> JSVal -> IO Viewer
newViewer containerId opts = Viewer <$> js_newViewer containerId opts
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.destroy()"
  js_destroyViewer :: JSVal -> IO ()

-- | Must be called when the viewer is torn down (e.g. on component
-- unmount) - Cesium holds a WebGL context and an animation-frame loop
-- that otherwise leak.
destroyViewer :: Viewer -> IO ()
destroyViewer (Viewer v) = js_destroyViewer v
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.scene.backgroundColor = $2"
  js_setBackgroundColor :: JSVal -> JSVal -> IO ()

-- | Set the scene's clear color (visible wherever no globe\/sky is drawn).
setBackgroundColor :: Viewer -> Color -> IO ()
setBackgroundColor (Viewer v) c = js_setBackgroundColor v (unColor c)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.camera.flyTo({ destination: $2 })"
  js_flyTo :: JSVal -> JSVal -> IO ()

-- | Animate the camera to a destination position.
flyTo :: Viewer -> Cartesian3 -> IO ()
flyTo (Viewer v) dest = js_flyTo v (unCartesian3 dest)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.camera.setView($2)"
  js_setView :: JSVal -> JSVal -> IO ()

-- | Snap the camera to a position\/orientation with no animation.
-- @setView viewer destination heading pitch roll@ (heading\/pitch\/roll in
-- radians - see 'Cesium.Math.toRadians').
setView :: Viewer -> Cartesian3 -> Double -> Double -> Double -> IO ()
setView (Viewer v) dest heading pitch roll = do
  orientation <- newObject
  setPropNum orientation (str "heading") heading
  setPropNum orientation (str "pitch") pitch
  setPropNum orientation (str "roll") roll
  opts <- newObject
  setProp opts (str "destination") (unCartesian3 dest)
  setProp opts (str "orientation") orientation
  js_setView v opts
-----------------------------------------------------------------------------
