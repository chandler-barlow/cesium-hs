-----------------------------------------------------------------------------
-- |
-- Bindings for @Cesium.Viewer@ - Phase 1 of the checklist: just enough to
-- mount a globe and move the camera. See the project plan for the fuller
-- feature checklist (entities, data sources, imagery/terrain, 3D Tiles, ...).
-----------------------------------------------------------------------------
module Cesium.Viewer
  ( Viewer
  , newViewer
  , destroyViewer
  , flyTo
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @Cesium.Viewer@ instance.
newtype Viewer = Viewer JSVal
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
foreign import javascript unsafe
  "$1.camera.flyTo({ destination: Cesium.Cartesian3.fromDegrees($2, $3, $4) })"
  js_flyTo :: JSVal -> Double -> Double -> Double -> IO ()

-- | Fly the camera to a longitude\/latitude\/height (degrees, degrees,
-- metres).
flyTo :: Viewer -> Double -> Double -> Double -> IO ()
flyTo (Viewer v) = js_flyTo v
-----------------------------------------------------------------------------
