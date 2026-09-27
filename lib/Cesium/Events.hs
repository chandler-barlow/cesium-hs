-----------------------------------------------------------------------------
-- |
-- Phase 3 of the checklist: input handling via @Cesium.ScreenSpaceEventHandler@.
--
-- This is also where the Phase 0 "callback bridging" item gets exercised -
-- 'onLeftClick' uses GHC's @"wrapper"@ JSFFI import to turn a Haskell
-- closure into a callable 'JSVal' that Cesium can invoke directly.
--
-- __Note:__ the callback runs as plain 'IO' - it does not (yet) dispatch a
-- Miso 'Action'. Routing Cesium-originated events back into a component's
-- update loop (via @Miso.Effect.withSink@\/@issue@) is future checklist
-- work; for now, side effect from inside the callback directly (as
-- 'flyTo' does in the example), or hold an 'IORef' if you need to react
-- from outside it.
-----------------------------------------------------------------------------
module Cesium.Events
  ( ScreenSpaceEventHandler
  , newScreenSpaceEventHandler
  , onLeftClick
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @Cesium.ScreenSpaceEventHandler@ instance.
newtype ScreenSpaceEventHandler = ScreenSpaceEventHandler JSVal
-----------------------------------------------------------------------------
foreign import javascript unsafe
  "return new Cesium.ScreenSpaceEventHandler($1.scene.canvas)"
  js_newHandler :: JSVal -> IO JSVal

-- | Create an input handler bound to the viewer's canvas. Cesium's default
-- handler (rotate\/zoom\/tilt) keeps running alongside this one; use
-- 'Cesium.Viewer.setView' etc. yourself inside the callback if you need to
-- override that.
newScreenSpaceEventHandler :: Viewer -> IO ScreenSpaceEventHandler
newScreenSpaceEventHandler v = ScreenSpaceEventHandler <$> js_newHandler (unViewer v)
-----------------------------------------------------------------------------
foreign import javascript "wrapper"
  js_wrapClickCallback :: (JSVal -> IO ()) -> IO JSVal

foreign import javascript unsafe
  "$1.setInputAction($2, Cesium.ScreenSpaceEventType.LEFT_CLICK)"
  js_setInputActionLeftClick :: JSVal -> JSVal -> IO ()

-- | Register a callback for left-click. The 'JSVal' passed to it is the
-- raw event object (@{ position: Cartesian2 }@ in screen coordinates) -
-- pick it apart with "Cesium.Core"'s 'getProp' as needed.
onLeftClick :: ScreenSpaceEventHandler -> (JSVal -> IO ()) -> IO ()
onLeftClick (ScreenSpaceEventHandler h) cb = do
  cbVal <- js_wrapClickCallback cb
  js_setInputActionLeftClick h cbVal
-----------------------------------------------------------------------------
