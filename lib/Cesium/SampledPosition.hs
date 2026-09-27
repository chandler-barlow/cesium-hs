-----------------------------------------------------------------------------
-- |
-- @Cesium.SampledPositionProperty@ - a time-dynamic position built from
-- discrete samples, with Cesium interpolating smoothly between them as its
-- clock advances. This is what makes the flight tracker demo glide
-- between polls instead of popping: rather than recreating an entity each
-- poll, add a new time-tagged sample to its existing position property.
-----------------------------------------------------------------------------
module Cesium.SampledPosition
  ( SampledPositionProperty
  , unSampledPositionProperty
  , newSampledPositionProperty
  , addSample
  , setForwardExtrapolationType
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Math (Cartesian3, JulianDate, unCartesian3, unJulianDate)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @Cesium.SampledPositionProperty@ instance.
newtype SampledPositionProperty = SampledPositionProperty JSVal

unSampledPositionProperty :: SampledPositionProperty -> JSVal
unSampledPositionProperty (SampledPositionProperty v) = v
-----------------------------------------------------------------------------
foreign import javascript unsafe "return new Cesium.SampledPositionProperty()"
  js_newSampledPositionProperty :: IO JSVal

newSampledPositionProperty :: IO SampledPositionProperty
newSampledPositionProperty = SampledPositionProperty <$> js_newSampledPositionProperty
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.addSample($2, $3)"
  js_addSample :: JSVal -> JSVal -> JSVal -> IO ()

-- | Record a position at a point in time. Add samples in chronological
-- order (Cesium's own recommendation) - which is naturally what polling
-- and always adding "now" does.
addSample :: SampledPositionProperty -> JulianDate -> Cartesian3 -> IO ()
addSample (SampledPositionProperty p) t pos =
  js_addSample p (unJulianDate t) (unCartesian3 pos)
-----------------------------------------------------------------------------
foreign import javascript unsafe
  "$1.forwardExtrapolationType = Cesium.ExtrapolationType.EXTRAPOLATE"
  js_setForwardExtrapolationType :: JSVal -> IO ()

-- | Without this, Cesium's default (@ExtrapolationType.NONE@) makes the
-- entity vanish once the clock passes the most recent sample's time -
-- which happens briefly on every poll, in the gap between "now" and the
-- next sample actually arriving. @EXTRAPOLATE@ continues along the last
-- known direction\/rate instead, so the aircraft keeps gliding through
-- that gap rather than disappearing or freezing.
setForwardExtrapolationType :: SampledPositionProperty -> IO ()
setForwardExtrapolationType (SampledPositionProperty p) = js_setForwardExtrapolationType p
-----------------------------------------------------------------------------
