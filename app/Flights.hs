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
-- Each aircraft is tracked by its @hex@ (ICAO24) across polls via a
-- 'Cesium.SampledPositionProperty' - a new poll adds a new time-tagged
-- sample to an *existing* aircraft's position instead of recreating its
-- entity, so it glides smoothly between reported positions rather than
-- popping. Only genuinely new aircraft get a new entity; aircraft that
-- drop out of the feed get their entity removed.
--
-- Demo-specific glue, not a Cesium binding - this is why it lives in
-- @app\/@ rather than @lib\/Cesium@.
-----------------------------------------------------------------------------
module Flights
  ( pollUSFlights
  ) where
-----------------------------------------------------------------------------
import Control.Exception (SomeException, try)
import Control.Monad (foldM)
import Data.IORef
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import qualified Cesium
import qualified Cesium.Browser as Browser
import qualified Cesium.Options as Options
import qualified Cesium.Simple as Simple
-----------------------------------------------------------------------------
-- | An aircraft's live-updating entity plus the position property that
-- makes it move - both are kept, since new samples get added to the
-- latter without touching the former.
data Tracked = Tracked
  { trackedEntity :: Cesium.Entity
  , trackedPosition :: Cesium.SampledPositionProperty
  }
-----------------------------------------------------------------------------
-- | A small top-down airplane silhouette - tapered fuselage, swept main
-- wings, swept tail wings, each a simple 4-point quadrilateral (no
-- curves) so the shape is easy to get right without a browser to preview
-- it in. Screen-upright by default (nose at the top); fill color set via
-- percent-encoded @#@, since a literal @#@ would truncate a data URI at
-- the fragment. Fully self-contained - no network dependency for the
-- icon itself, unlike the flight data.
planeIcon :: String
planeIcon =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 24 24'%3E%3Cpath d='M12 0 L13 4 L13 22 L11 22 L11 4 Z M13 9 L24 13 L24 14 L13 12 Z M11 9 L0 13 L0 14 L11 12 Z M13 18 L19 20.5 L19 21.5 L13 20 Z M11 18 L5 20.5 L5 21.5 L11 20 Z' fill='%2300e5ff' stroke='%23012026' stroke-width='0.5'/%3E%3C/svg%3E"
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
-- every 5 seconds. adsb.lol's exact rate limit isn't documented, but a
-- single request every 5s is comfortably conservative for a community
-- API (rapid manual testing against it directly got HTTP 429 back, which
-- is a good reminder this is a shared resource, not our own server).
-- Combined with SampledPositionProperty smoothing, 5s polling gives
-- genuinely continuous-looking motion rather than long straight-line
-- glides between distant points.
pollUSFlights :: Cesium.Viewer -> IO ()
pollUSFlights viewer = do
  trackedRef <- newIORef Map.empty
  -- Subtle from the full-US overview, easier to make out once you've
  -- zoomed in on one - see Cesium.Math.nearFarScalar's docs for how the
  -- two distances clamp outside their range.
  iconScale <- Cesium.nearFarScalar 1000 1.5 1000000 0.5
  let poll = pollOnce viewer iconScale trackedRef
  poll
  Browser.setInterval poll 5000
-----------------------------------------------------------------------------
pollOnce :: Cesium.Viewer -> Cesium.NearFarScalar -> IORef (Map String Tracked) -> IO ()
pollOnce viewer iconScale trackedRef = do
  result <- try (Browser.fetchJson proxyUrl) :: IO (Either SomeException Cesium.JSVal)
  case result of
    Left err ->
      Cesium.consoleError (Cesium.str
        ("flight poll failed - is `cabal run adsb-proxy` running? " ++ show err))
    Right json -> do
      now <- Cesium.julianDateNow
      aircraft <- Cesium.getProp json (Cesium.str "ac")
      len <- Cesium.arrayLength aircraft
      old <- readIORef trackedRef
      new <- foldM (updateOne viewer iconScale now old aircraft) Map.empty [0 .. round len - 1]
      -- anything present before this poll but not seen in it has left the feed
      mapM_ (Cesium.removeEntity viewer . trackedEntity) (Map.elems (Map.difference old new))
      writeIORef trackedRef new
-----------------------------------------------------------------------------
updateOne
  :: Cesium.Viewer
  -> Cesium.NearFarScalar
  -> Cesium.JulianDate
  -> Map String Tracked
  -> Cesium.JSVal
  -> Map String Tracked
  -> Int
  -> IO (Map String Tracked)
updateOne viewer iconScale now old aircraft acc i = do
  ac <- Cesium.arrayIndex aircraft (fromIntegral i)
  hex <- Cesium.unstr <$> Cesium.getPropStrOr ac (Cesium.str "hex") (Cesium.str "")
  hasPosition <- (&&)
    <$> Cesium.hasNumProp ac (Cesium.str "lat")
    <*> Cesium.hasNumProp ac (Cesium.str "lon")
  if null hex || not hasPosition
    then pure acc
    else do
      lat <- Cesium.getPropNumOr ac (Cesium.str "lat") 0
      lon <- Cesium.getPropNumOr ac (Cesium.str "lon") 0
      altitudeFt <- Cesium.getPropNumOr ac (Cesium.str "alt_baro") 0
      track <- Cesium.getPropNumOr ac (Cesium.str "track") 0
      pos <- Cesium.cartesian3FromDegrees lon lat (altitudeFt * 0.3048)
      let rotation = negate (Cesium.toRadians track)
      case Map.lookup hex old of
        Just tracked -> do
          -- already on the globe - just add a new sample and refresh
          -- heading, no entity churn at all
          Cesium.addSample (trackedPosition tracked) now pos
          Cesium.setBillboardRotation (trackedEntity tracked) rotation
          pure (Map.insert hex tracked acc)
        Nothing -> do
          -- new aircraft - create its position property and entity once
          posProp <- Cesium.newSampledPositionProperty
          Cesium.setForwardExtrapolationType posProp
          Cesium.addSample posProp now pos
          billboard <- Options.toOptions Simple.defaultBillboardOptions
            { Simple.image = Just planeIcon
            , Simple.rotation = Just rotation
            , Simple.scaleByDistance = Just iconScale
            }
          opts <- Cesium.newObject
          Cesium.setProp opts (Cesium.str "position") (Cesium.unSampledPositionProperty posProp)
          Cesium.setProp opts (Cesium.str "billboard") billboard
          entity <- Cesium.addEntity viewer opts
          pure (Map.insert hex (Tracked entity posProp) acc)
-----------------------------------------------------------------------------
