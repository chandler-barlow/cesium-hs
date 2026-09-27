-----------------------------------------------------------------------------
-- |
-- Phase 2 of the checklist: core math\/value types - just enough surface to
-- describe positions, colors, and areas without dropping into raw
-- "Cesium.Core" object-building at every call site.
-----------------------------------------------------------------------------
module Cesium.Math
  ( Cartesian3
  , unCartesian3
  , cartesian3FromDegrees
  , cartesian3FromRadians
  , Cartographic
  , cartographicFromDegrees
  , cartographicFromRadians
  , Color
  , unColor
  , colorFromCss
  , colorNamed
  , Rectangle
  , rectangleFromDegrees
  , Matrix4
  , matrix4Identity
  , Quaternion
  , quaternionFromAxisAngle
  , JulianDate
  , julianDateNow
  , toRadians
  , toDegrees
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
-----------------------------------------------------------------------------
-- | A 3D Cartesian point, in metres, in Cesium's fixed-frame (ECEF)
-- coordinates.
newtype Cartesian3 = Cartesian3 JSVal

-- | Escape hatch for other "Cesium.*" modules that need to pass a
-- 'Cartesian3' into a raw FFI import.
unCartesian3 :: Cartesian3 -> JSVal
unCartesian3 (Cartesian3 v) = v

foreign import javascript unsafe "return Cesium.Cartesian3.fromDegrees($1, $2, $3)"
  js_cartesian3FromDegrees :: Double -> Double -> Double -> IO JSVal

-- | @cartesian3FromDegrees longitude latitude height@ (degrees, degrees,
-- metres above the ellipsoid).
cartesian3FromDegrees :: Double -> Double -> Double -> IO Cartesian3
cartesian3FromDegrees lon lat h = Cartesian3 <$> js_cartesian3FromDegrees lon lat h

foreign import javascript unsafe "return Cesium.Cartesian3.fromRadians($1, $2, $3)"
  js_cartesian3FromRadians :: Double -> Double -> Double -> IO JSVal

cartesian3FromRadians :: Double -> Double -> Double -> IO Cartesian3
cartesian3FromRadians lon lat h = Cartesian3 <$> js_cartesian3FromRadians lon lat h
-----------------------------------------------------------------------------
-- | A geodetic longitude\/latitude\/height triple (radians, radians,
-- metres) - Cesium's preferred way to talk about a point on the ellipsoid
-- before it becomes a 'Cartesian3'.
newtype Cartographic = Cartographic JSVal

foreign import javascript unsafe "return Cesium.Cartographic.fromDegrees($1, $2, $3)"
  js_cartographicFromDegrees :: Double -> Double -> Double -> IO JSVal

cartographicFromDegrees :: Double -> Double -> Double -> IO Cartographic
cartographicFromDegrees lon lat h = Cartographic <$> js_cartographicFromDegrees lon lat h

foreign import javascript unsafe "return Cesium.Cartographic.fromRadians($1, $2, $3)"
  js_cartographicFromRadians :: Double -> Double -> Double -> IO JSVal

cartographicFromRadians :: Double -> Double -> Double -> IO Cartographic
cartographicFromRadians lon lat h = Cartographic <$> js_cartographicFromRadians lon lat h
-----------------------------------------------------------------------------
-- | An RGBA color. Opaque - go through 'colorFromCss'\/'colorNamed' to
-- build one, 'unColor' to hand it to another binding module's FFI import.
newtype Color = Color JSVal

unColor :: Color -> JSVal
unColor (Color v) = v

foreign import javascript unsafe "return Cesium.Color.fromCssColorString($1)"
  js_colorFromCss :: JSString -> IO JSVal

-- | Any CSS color string: @\"#336699\"@, @\"rgb(51,102,153)\"@, @\"steelblue\"@.
colorFromCss :: String -> IO Color
colorFromCss = fmap Color . js_colorFromCss . str

foreign import javascript unsafe "return Cesium.Color[$1]"
  js_colorNamed :: JSString -> IO JSVal

-- | One of Cesium's built-in named colors, e.g. @colorNamed \"RED\"@ - see
-- the @Cesium.Color@ docs for the full list.
colorNamed :: String -> IO Color
colorNamed = fmap Color . js_colorNamed . str
-----------------------------------------------------------------------------
-- | An axis-aligned region described by west\/south\/east\/north bounds.
newtype Rectangle = Rectangle JSVal

foreign import javascript unsafe "return Cesium.Rectangle.fromDegrees($1, $2, $3, $4)"
  js_rectangleFromDegrees :: Double -> Double -> Double -> Double -> IO JSVal

-- | @rectangleFromDegrees west south east north@, all in degrees.
rectangleFromDegrees :: Double -> Double -> Double -> Double -> IO Rectangle
rectangleFromDegrees w s e n = Rectangle <$> js_rectangleFromDegrees w s e n
-----------------------------------------------------------------------------
-- | A 4x4 transform matrix. Only the identity is bound so far - the rest of
-- the @Matrix4@\/@Transforms@ surface is future checklist work, added once
-- something downstream (e.g. model placement) actually needs it.
newtype Matrix4 = Matrix4 JSVal

foreign import javascript unsafe "return Cesium.Matrix4.IDENTITY"
  js_matrix4Identity :: IO JSVal

matrix4Identity :: IO Matrix4
matrix4Identity = Matrix4 <$> js_matrix4Identity
-----------------------------------------------------------------------------
-- | A rotation, as used by e.g. entity/model orientation.
newtype Quaternion = Quaternion JSVal

foreign import javascript unsafe "return Cesium.Quaternion.fromAxisAngle($1, $2)"
  js_quaternionFromAxisAngle :: JSVal -> Double -> IO JSVal

-- | @quaternionFromAxisAngle axis angleRadians@.
quaternionFromAxisAngle :: Cartesian3 -> Double -> IO Quaternion
quaternionFromAxisAngle (Cartesian3 axis) angle =
  Quaternion <$> js_quaternionFromAxisAngle axis angle
-----------------------------------------------------------------------------
-- | An instant in time, in Cesium's own calendar representation.
newtype JulianDate = JulianDate JSVal

foreign import javascript unsafe "return Cesium.JulianDate.now()"
  js_julianDateNow :: IO JSVal

julianDateNow :: IO JulianDate
julianDateNow = JulianDate <$> js_julianDateNow
-----------------------------------------------------------------------------
-- | Pure - no need to round-trip through JS for basic trig conversions.
toRadians :: Double -> Double
toRadians d = d * pi / 180

toDegrees :: Double -> Double
toDegrees r = r * 180 / pi
-----------------------------------------------------------------------------
