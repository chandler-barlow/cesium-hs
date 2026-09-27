-----------------------------------------------------------------------------
-- |
-- Generic browser Web API bindings that aren't Cesium-specific, but are
-- needed to build anything that pulls in live external data (e.g. the
-- flight tracker demo) - HTTP fetch and timers.
-----------------------------------------------------------------------------
module Cesium.Browser
  ( fetchJson
  , setInterval
  , nowMs
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core (str)
-----------------------------------------------------------------------------
foreign import javascript safe "return await (await fetch($1)).json()"
  js_fetchJson :: JSString -> IO JSVal

-- | Fetch a URL and parse the response body as JSON, returning the live
-- parsed value - walk it with "Cesium.Core"'s @getProp@\/@arrayIndex@\/
-- @getPropNumOr@\/etc. A network error (including a CORS rejection)
-- throws a catchable @JSException@; a non-2xx HTTP status does __not__ -
-- this doesn't check @response.ok@, so a 404\/500 with a JSON error body
-- still "succeeds" and returns that body.
fetchJson :: String -> IO JSVal
fetchJson = js_fetchJson . str
-----------------------------------------------------------------------------
foreign import javascript "wrapper"
  js_wrapIntervalCallback :: IO () -> IO JSVal

foreign import javascript unsafe "setInterval($1, $2)"
  js_setInterval :: JSVal -> Double -> IO ()

-- | Run an action every @intervalMs@ milliseconds (starting after the
-- first interval elapses, not immediately - call the action once
-- yourself first if you want it to run right away too). Runs forever;
-- there's no @clearInterval@ exposed yet, nothing has needed to stop one.
setInterval :: IO () -> Double -> IO ()
setInterval action intervalMs = do
  cb <- js_wrapIntervalCallback action
  js_setInterval cb intervalMs
-----------------------------------------------------------------------------
-- | Milliseconds since the Unix epoch - for simple wall-clock cooldowns
-- (e.g. "don't refetch more than once every N seconds even if several
-- triggers fire close together").
foreign import javascript unsafe "return Date.now()"
  nowMs :: IO Double
-----------------------------------------------------------------------------
