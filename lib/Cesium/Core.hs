-----------------------------------------------------------------------------
-- |
-- Low-level FFI primitives shared by every Cesium binding module.
--
-- Everything here is a thin wrapper over GHC's wasm JSFFI ("GHC.Wasm.Prim")
-- - opaque 'JSVal' handles plus helpers for building\/reading JS object
-- literals, since Cesium's own constructors take large, mostly-optional
-- options objects rather than positional arguments.
-----------------------------------------------------------------------------
module Cesium.Core
  ( JSVal
  , JSString
  , str
  , newObject
  , setProp
  , setPropStr
  , setPropNum
  , setPropBool
  , getProp
  , global
  , consoleLog
  , newArray
  , arrayPush
  , arrayLength
  , arrayIndex
  , num
  , setIonAccessToken
  , consoleError
  , hasNumProp
  , getPropNumOr
  , getPropStrOr
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim
-----------------------------------------------------------------------------
-- | Shorthand for 'toJSString'.
str :: String -> JSString
str = toJSString
-----------------------------------------------------------------------------
foreign import javascript unsafe "return {}"
  js_newObject :: IO JSVal

-- | A fresh, empty JS object literal - the starting point for building an
-- options bag to hand to a Cesium constructor.
newObject :: IO JSVal
newObject = js_newObject
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1[$2] = $3"
  setProp :: JSVal -> JSString -> JSVal -> IO ()

foreign import javascript unsafe "$1[$2] = $3"
  setPropStr :: JSVal -> JSString -> JSString -> IO ()

foreign import javascript unsafe "$1[$2] = $3"
  setPropNum :: JSVal -> JSString -> Double -> IO ()

foreign import javascript unsafe "$1[$2] = !!$3"
  setPropBool :: JSVal -> JSString -> Bool -> IO ()
-----------------------------------------------------------------------------
foreign import javascript unsafe "return $1[$2]"
  getProp :: JSVal -> JSString -> IO JSVal
-----------------------------------------------------------------------------
-- | Look up a name on @globalThis@, e.g. @global (str \"Cesium\")@.
foreign import javascript unsafe "return globalThis[$1]"
  global :: JSString -> IO JSVal
-----------------------------------------------------------------------------
-- | Handy for poking at an opaque 'JSVal' (e.g. an event object) from the
-- browser devtools console while wiring up a new binding.
foreign import javascript unsafe "console.log($1)"
  consoleLog :: JSVal -> IO ()
-----------------------------------------------------------------------------
-- | A fresh, empty JS array - Cesium accepts plain arrays for e.g. a
-- polyline's @positions@ or a polygon's @hierarchy@.
foreign import javascript unsafe "return []"
  newArray :: IO JSVal

foreign import javascript unsafe "$1.push($2)"
  arrayPush :: JSVal -> JSVal -> IO ()
-----------------------------------------------------------------------------
foreign import javascript unsafe "return $1.length"
  arrayLength :: JSVal -> IO Double

foreign import javascript unsafe "return $1[$2]"
  arrayIndex :: JSVal -> Double -> IO JSVal
-----------------------------------------------------------------------------
-- | Box a raw number as a 'JSVal', e.g. for pushing into an array built
-- with 'newArray'\/'arrayPush' (object properties can go straight through
-- 'setPropNum' instead).
foreign import javascript unsafe "return $1"
  num :: Double -> IO JSVal
-----------------------------------------------------------------------------
-- | Required before using any Cesium Ion asset (world imagery/terrain,
-- hosted 3D Tiles, ...) - get a token from https://ion.cesium.com.
foreign import javascript unsafe "Cesium.Ion.defaultAccessToken = $1"
  js_setIonAccessToken :: JSString -> IO ()

setIonAccessToken :: String -> IO ()
setIonAccessToken = js_setIonAccessToken . str
-----------------------------------------------------------------------------
foreign import javascript unsafe "console.error($1)"
  consoleError :: JSString -> IO ()
-----------------------------------------------------------------------------
-- | These three are for walking JSON parsed from an external source (e.g.
-- 'Cesium.Browser.fetchJson') where a field's presence and type aren't
-- guaranteed - unlike Cesium's own API objects, which we control the
-- shape of by construction.
foreign import javascript unsafe "return typeof $1[$2] === 'number'"
  hasNumProp :: JSVal -> JSString -> IO Bool

-- | @getPropNumOr obj key fallback@ - @fallback@ if the field is missing
-- or isn't actually a JS number (e.g. adsb.lol's @alt_baro@, which can be
-- the literal string @\"ground\"@).
foreign import javascript unsafe
  "return (typeof $1[$2] === 'number') ? $1[$2] : $3"
  getPropNumOr :: JSVal -> JSString -> Double -> IO Double

-- | As 'getPropNumOr', for string-typed fields.
foreign import javascript unsafe
  "return (typeof $1[$2] === 'string') ? $1[$2] : $3"
  getPropStrOr :: JSVal -> JSString -> JSString -> IO JSString
-----------------------------------------------------------------------------
