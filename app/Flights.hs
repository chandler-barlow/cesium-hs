-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- |
-- Live public flights, via the local @adsb-proxy@ (see @proxy\/Main.hs@) -
-- adsb.lol has real free global aircraft data but no CORS, so this talks
-- to our own proxy instead of adsb.lol directly.
--
-- Demo-specific glue, not a Cesium binding - this is why it lives in
-- @app\/@ rather than @lib\/Cesium@.
-----------------------------------------------------------------------------
module Flights
  ( FlightQuery(..)
  , pollFlights
  ) where
-----------------------------------------------------------------------------
import Control.Exception (SomeException, try)
import Data.IORef

import qualified Cesium
import qualified Cesium.Browser as Browser
import qualified Cesium.Simple as Simple
-----------------------------------------------------------------------------
data FlightQuery = FlightQuery
  { fqLat :: Double
  , fqLon :: Double
  , fqRadiusNm :: Double
  }
-----------------------------------------------------------------------------
proxyUrl :: FlightQuery -> String
proxyUrl q =
  "http://localhost:8790/flights?lat=" ++ show (fqLat q)
    ++ "&lon=" ++ show (fqLon q)
    ++ "&radius=" ++ show (fqRadiusNm q)
-----------------------------------------------------------------------------
-- | Start polling for aircraft near @query@, once immediately and then
-- every 15 seconds - comfortably under any reasonable rate limit for a
-- community API like adsb.lol, while still feeling "live". Every poll
-- clears all previously-added entities and re-adds fresh ones; there's no
-- position smoothing/diffing yet, so expect a small pop each refresh
-- rather than a smooth glide - good enough to prove the library handles
-- hundreds of live-updating entities, not meant as a polished result.
pollFlights :: Cesium.Viewer -> FlightQuery -> IO ()
pollFlights viewer query = do
  entitiesRef <- newIORef []
  color <- Cesium.colorNamed "CYAN"
  let poll = pollOnce viewer query color entitiesRef
  poll
  Browser.setInterval poll 15000
-----------------------------------------------------------------------------
pollOnce :: Cesium.Viewer -> FlightQuery -> Cesium.Color -> IORef [Cesium.Entity] -> IO ()
pollOnce viewer query color entitiesRef = do
  result <- try (Browser.fetchJson (proxyUrl query)) :: IO (Either SomeException Cesium.JSVal)
  case result of
    Left err ->
      Cesium.consoleError (Cesium.str
        ("flight poll failed - is `cabal run adsb-proxy` running? " ++ show err))
    Right json -> do
      old <- readIORef entitiesRef
      mapM_ (Cesium.removeEntity viewer) old
      aircraft <- Cesium.getProp json (Cesium.str "ac")
      len <- Cesium.arrayLength aircraft
      new <- mapM (addAircraft viewer aircraft color) [0 .. round len - 1]
      writeIORef entitiesRef [ e | Just e <- new ]
-----------------------------------------------------------------------------
addAircraft :: Cesium.Viewer -> Cesium.JSVal -> Cesium.Color -> Int -> IO (Maybe Cesium.Entity)
addAircraft viewer aircraft color i = do
  ac <- Cesium.arrayIndex aircraft (fromIntegral i)
  hasPosition <- (&&)
    <$> Cesium.hasNumProp ac (Cesium.str "lat")
    <*> Cesium.hasNumProp ac (Cesium.str "lon")
  if not hasPosition
    then pure Nothing
    else do
      lat <- Cesium.getPropNumOr ac (Cesium.str "lat") 0
      lon <- Cesium.getPropNumOr ac (Cesium.str "lon") 0
      altitudeFt <- Cesium.getPropNumOr ac (Cesium.str "alt_baro") 0
      pos <- Cesium.cartesian3FromDegrees lon lat (altitudeFt * 0.3048)
      entity <- Simple.addPointEntity viewer pos Simple.defaultPointOptions
        { Simple.pixelSize = Just 6
        , Simple.color = Just color
        }
      pure (Just entity)
-----------------------------------------------------------------------------
