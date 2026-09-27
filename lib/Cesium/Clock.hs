-----------------------------------------------------------------------------
-- |
-- Phase 9 of the checklist (clock half): @viewer.clock@ - playback controls
-- for time-dynamic data (CZML, entity availability, ...).
--
-- @TimeIntervalCollection@ isn't bound yet - nothing above needs it so far;
-- same pattern, added when something does.
-----------------------------------------------------------------------------
module Cesium.Clock
  ( setClockShouldAnimate
  , setClockMultiplier
  , setClockRange
  , setClockCurrentTime
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
import Cesium.Math (JulianDate, unJulianDate)
import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.clock.shouldAnimate = $2"
  js_setClockShouldAnimate :: JSVal -> Bool -> IO ()

setClockShouldAnimate :: Viewer -> Bool -> IO ()
setClockShouldAnimate v = js_setClockShouldAnimate (unViewer v)
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.clock.multiplier = $2"
  js_setClockMultiplier :: JSVal -> Double -> IO ()

-- | Simulation seconds per wall-clock second, e.g. @60@ for 1 minute\/sec.
setClockMultiplier :: Viewer -> Double -> IO ()
setClockMultiplier v = js_setClockMultiplier (unViewer v)
-----------------------------------------------------------------------------
foreign import javascript unsafe "return Cesium.ClockRange[$1]"
  js_clockRangeNamed :: JSString -> IO JSVal

foreign import javascript unsafe "$1.clock.clockRange = $2"
  js_setClockRangeRaw :: JSVal -> JSVal -> IO ()

-- | One of @\"UNBOUNDED\"@, @\"CLAMPED\"@, @\"LOOP_STOP\"@.
setClockRange :: Viewer -> String -> IO ()
setClockRange v name = do
  cr <- js_clockRangeNamed (str name)
  js_setClockRangeRaw (unViewer v) cr
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.clock.currentTime = $2"
  js_setClockCurrentTime :: JSVal -> JSVal -> IO ()

setClockCurrentTime :: Viewer -> JulianDate -> IO ()
setClockCurrentTime v jd = js_setClockCurrentTime (unViewer v) (unJulianDate jd)
-----------------------------------------------------------------------------
