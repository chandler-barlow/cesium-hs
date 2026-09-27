-----------------------------------------------------------------------------
{-# LANGUAGE CPP               #-}
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
module Main where
-----------------------------------------------------------------------------
import           Miso
import           Miso.CSS (styleInline_)
import           Miso.Html.Element as H
import           Miso.Html.Property as P
-----------------------------------------------------------------------------
import qualified Cesium
-----------------------------------------------------------------------------
data Model = Model
  deriving (Show, Eq)
-----------------------------------------------------------------------------
data Action
  = Init
  | NoOp
  deriving (Show, Eq)
-----------------------------------------------------------------------------
#ifdef WASM
foreign export javascript "hs_start" main :: IO ()
#endif
-----------------------------------------------------------------------------
main :: IO ()
main = startApp defaultEvents app
-----------------------------------------------------------------------------
app :: App Model Action
app = (component Model updateModel viewModel)
  { mount = Just Init
  }
-----------------------------------------------------------------------------
updateModel :: Action -> Effect context props Model Action
updateModel = \case
  Init -> io_ initCesium
  NoOp -> pure ()
-----------------------------------------------------------------------------
-- | Runs once, after Miso mounts "#cesium-container" into the real DOM.
-- From here on Cesium owns that element's subtree - 'viewModel' must never
-- change its children, or Miso's vdom diff will fight Cesium for control
-- of the canvas it injects.
initCesium :: IO ()
initCesium = do
  opts <- Cesium.newObject
  viewer <- Cesium.newViewer (Cesium.str "cesium-container") opts

  -- Phase 2: Cartesian3 + Color, Phase 3: setView (straight down, no animation)
  nyc <- Cesium.cartesian3FromDegrees (-74.0060) 40.7128 15000000
  Cesium.setView viewer nyc 0 (Cesium.toRadians (-90)) 0
  bg <- Cesium.colorFromCss "#000010"
  Cesium.setBackgroundColor viewer bg

  -- Phase 4: a point + label entity to click on
  london <- Cesium.cartesian3FromDegrees (-0.1276) 51.5074 0
  red <- Cesium.colorNamed "RED"
  _ <- Cesium.addPointEntity viewer london 12 red
  _ <- Cesium.addLabelEntity viewer london "London"

  -- Phase 3 + 4: click handling via the "wrapper" JSFFI callback bridge,
  -- picking whatever entity (if any) is under the cursor
  handler <- Cesium.newScreenSpaceEventHandler viewer
  Cesium.onLeftClick handler $ \ev -> do
    screenPos <- Cesium.getProp ev (Cesium.str "position")
    picked <- Cesium.pick viewer screenPos
    Cesium.consoleLog picked
    londonDest <- Cesium.cartesian3FromDegrees (-0.1276) 51.5074 5000000
    Cesium.flyTo viewer londonDest

  -- Phase 5: an inline GeoJSON point, loaded through a genuinely async
  -- Cesium call (exercises the Phase 0 "Promise bridging" item)
  geojson <- parisGeoJson
  geojsonOpts <- Cesium.newObject
  dataSource <- Cesium.loadGeoJsonData geojson geojsonOpts
  _ <- Cesium.addDataSource viewer dataSource

  -- Phase 6: an extra OSM tile layer at half alpha, over an explicit
  -- (procedural, no-network) terrain provider
  imageryOpts <- Cesium.newObject
  Cesium.setPropStr imageryOpts (Cesium.str "url") (Cesium.str "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
  provider <- Cesium.urlTemplateImageryProvider imageryOpts
  layer <- Cesium.addImageryLayer viewer provider
  Cesium.setImageryLayerAlpha layer 0.5

  terrain <- Cesium.ellipsoidTerrainProvider
  Cesium.setTerrainProvider viewer terrain

  -- Phase 9: scene/globe/clock toggles
  configureSceneAndClock viewer
-----------------------------------------------------------------------------
-- | Phase 9: a scene/globe/clock configuration pass, kept separate from
-- 'initCesium' just for readability.
configureSceneAndClock :: Cesium.Viewer -> IO ()
configureSceneAndClock viewer = do
  Cesium.setFogEnabled viewer True
  Cesium.setSkyAtmosphereShow viewer True
  Cesium.setMsaaSamples viewer 4

  globeColor <- Cesium.colorFromCss "#001a33"
  Cesium.setGlobeBaseColor viewer globeColor
  Cesium.setDepthTestAgainstTerrain viewer True
  Cesium.setGlobeTranslucency viewer True 0.8

  currentTime <- Cesium.julianDateNow
  Cesium.setClockCurrentTime viewer currentTime
  Cesium.setClockShouldAnimate viewer True
  Cesium.setClockMultiplier viewer 60
  Cesium.setClockRange viewer "LOOP_STOP"
-----------------------------------------------------------------------------
-- | A minimal GeoJSON @FeatureCollection@ (one @Point@), built directly
-- with "Cesium.Core"'s object\/array helpers - no network fetch needed to
-- demonstrate 'Cesium.loadGeoJsonData'.
parisGeoJson :: IO Cesium.JSVal
parisGeoJson = do
  lon <- Cesium.num 2.3522
  lat <- Cesium.num 48.8566
  coords <- Cesium.newArray
  Cesium.arrayPush coords lon
  Cesium.arrayPush coords lat

  geometry <- Cesium.newObject
  Cesium.setPropStr geometry (Cesium.str "type") (Cesium.str "Point")
  Cesium.setProp geometry (Cesium.str "coordinates") coords

  properties <- Cesium.newObject
  Cesium.setPropStr properties (Cesium.str "name") (Cesium.str "Paris")

  feature <- Cesium.newObject
  Cesium.setPropStr feature (Cesium.str "type") (Cesium.str "Feature")
  Cesium.setProp feature (Cesium.str "geometry") geometry
  Cesium.setProp feature (Cesium.str "properties") properties

  features <- Cesium.newArray
  Cesium.arrayPush features feature

  fc <- Cesium.newObject
  Cesium.setPropStr fc (Cesium.str "type") (Cesium.str "FeatureCollection")
  Cesium.setProp fc (Cesium.str "features") features
  pure fc
-----------------------------------------------------------------------------
viewModel :: Model -> View context props Model Action
viewModel _ =
  H.div_ []
  [ H.div_
    [ P.id_ "cesium-container"
    , styleInline_ "position:absolute;top:0;left:0;width:100%;height:100%;"
    ]
    []
  ]
-----------------------------------------------------------------------------
