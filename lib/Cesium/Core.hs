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
