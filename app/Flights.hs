-----------------------------------------------------------------------------
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings      #-}
-----------------------------------------------------------------------------
-- |
-- Live public flights, via the local @adsb-proxy@ (see @proxy\/Main.hs@) -
-- adsb.lol has real free global aircraft data but no CORS, so this talks
-- to our own proxy instead of adsb.lol directly.
--
-- One query, centered near the geographic center of the contiguous US
-- (Lebanon, Kansas) at a 1500nm radius, covers essentially the whole
-- country - tested by hand against adsb.lol directly: 2000nm barely adds
-- aircraft over 1500nm (1482 vs. 1460, from a spot check), so there's no
-- real coverage gap being traded away for a rounder number.
--
-- Demo-specific glue, not a Cesium binding - this is why it lives in
-- @app\/@ rather than @lib\/Cesium@.
-----------------------------------------------------------------------------
module Flights
  ( pollUSFlights
  ) where
-----------------------------------------------------------------------------
import Control.Exception (SomeException, try)
import Data.IORef

import qualified Cesium
import qualified Cesium.Browser as Browser
import qualified Cesium.Simple as Simple
-----------------------------------------------------------------------------
-- | Screen-upright dart icon (fill color set via percent-encoded @#@,
-- since a literal @#@ would truncate a data URI at the fragment). Fully
-- self-contained - no network dependency for the icon itself, unlike the
-- flight data.
planeIcon :: String
planeIcon =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'%3E%3Cpath d='M12 1 L18 21 L12 17 L6 21 Z' fill='%2300e5ff' stroke='%23012026' stroke-width='1'/%3E%3C/svg%3E"
-----------------------------------------------------------------------------
usCenterLat, usCenterLon, usRadiusNm :: Double
usCenterLat = 39.5
usCenterLon = -98.35
usRadiusNm = 1500

proxyUrl :: String
proxyUrl =
  "http://localhost:8790/flights?lat=" ++ show usCenterLat
    ++ "&lon=" ++ show usCenterLon
    ++ "&radius=" ++ show usRadiusNm
-----------------------------------------------------------------------------
-- | Start polling for aircraft across the US, once immediately and then
-- every 15 seconds - comfortably under any reasonable rate limit for a
-- community API like adsb.lol (confirmed one exists: rapid manual testing
-- against adsb.lol directly got HTTP 429 back), while still feeling
-- "live". Every poll clears all previously-added entities and re-adds
-- fresh ones; there's no position smoothing/diffing yet, so expect a
-- small pop each refresh rather than a smooth glide - good enough to
-- prove the library handles well over a thousand live-updating entities,
-- not meant as a polished result.
pollUSFlights :: Cesium.Viewer -> IO ()
pollUSFlights viewer = do
  entitiesRef <- newIORef []
  let poll = pollOnce viewer entitiesRef
  poll
  Browser.setInterval poll 15000
-----------------------------------------------------------------------------
pollOnce :: Cesium.Viewer -> IORef [Cesium.Entity] -> IO ()
pollOnce viewer entitiesRef = do
  result <- try (Browser.fetchJson proxyUrl) :: IO (Either SomeException Cesium.JSVal)
  case result of
    Left err ->
      Cesium.consoleError (Cesium.str
        ("flight poll failed - is `cabal run adsb-proxy` running? " ++ show err))
    Right json -> do
      old <- readIORef entitiesRef
      mapM_ (Cesium.removeEntity viewer) old
      aircraft <- Cesium.getProp json (Cesium.str "ac")
      len <- Cesium.arrayLength aircraft
      new <- mapM (addAircraft viewer aircraft) [0 .. round len - 1]
      writeIORef entitiesRef [ e | Just e <- new ]
-----------------------------------------------------------------------------
addAircraft :: Cesium.Viewer -> Cesium.JSVal -> Int -> IO (Maybe Cesium.Entity)
addAircraft viewer aircraft i = do
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
      track <- Cesium.getPropNumOr ac (Cesium.str "track") 0
      pos <- Cesium.cartesian3FromDegrees lon lat (altitudeFt * 0.3048)
      entity <- Simple.addBillboardEntity viewer pos Simple.defaultBillboardOptions
        { Simple.image = Just planeIcon
        , Simple.rotation = Just (negate (Cesium.toRadians track))
        , Simple.scale = Just 0.6
        }
      pure (Just entity)
-----------------------------------------------------------------------------
