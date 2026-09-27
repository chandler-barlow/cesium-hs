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
  Cesium.flyTo viewer (-74.0060) 40.7128 15000000
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
