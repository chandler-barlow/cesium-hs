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
import qualified Cesium.Simple as Simple
-----------------------------------------------------------------------------
import qualified Flights
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
  -- Cesium.Simple: a generic-derived options record instead of hand-built
  -- newObject/setProp calls, covering the widgets everyone turns off
  viewer <- Simple.newViewer (Cesium.str "cesium-container") Simple.defaultViewerOptions
    { Simple.timeline = Just False
    , Simple.animation = Just False
    }

  -- Straight down over the geographic center of the US, high enough to
  -- see the whole country at once (see Flights.hs for why that center)
  usView <- Cesium.cartesian3FromDegrees (-98.35) 39.5 6000000
  Cesium.setView viewer usView 0 (Cesium.toRadians (-90)) 0
  bg <- Cesium.colorFromCss "#000010"
  Cesium.setBackgroundColor viewer bg

  -- Picking (click an aircraft to log it to the console) - kept as a
  -- minimal interaction; no longer flies anywhere on click
  handler <- Cesium.newScreenSpaceEventHandler viewer
  Cesium.onLeftClick handler $ \ev -> do
    screenPos <- Cesium.getProp ev (Cesium.str "position")
    picked <- Cesium.pick viewer screenPos
    Cesium.consoleLog picked

  -- An OSM tile layer at half alpha, over an explicit (procedural,
  -- no-network) terrain provider
  imageryOpts <- Cesium.newObject
  Cesium.setPropStr imageryOpts (Cesium.str "url") (Cesium.str "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
  provider <- Cesium.urlTemplateImageryProvider imageryOpts
  layer <- Cesium.addImageryLayer viewer provider
  Cesium.setImageryLayerAlpha layer 0.5

  terrain <- Cesium.ellipsoidTerrainProvider
  Cesium.setTerrainProvider viewer terrain

  -- Scene/globe/clock toggles
  configureSceneAndClock viewer

  -- Live flights across the whole US, via the local adsb-proxy - see
  -- docs/checklist.md and README for how to run it
  Flights.pollUSFlights viewer
-----------------------------------------------------------------------------
-- | A scene/globe/clock configuration pass, kept separate from
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
