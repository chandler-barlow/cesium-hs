-----------------------------------------------------------------------------
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors      #-}
-----------------------------------------------------------------------------
-- |
-- A higher-level, more ergonomic layer over the raw "Cesium.*" bindings,
-- built on "Cesium.Options"'s generic record-to-options-object machinery.
--
-- Import this __qualified__ alongside "Cesium" - it deliberately isn't
-- re-exported from the "Cesium" umbrella module, since several of its
-- names (@newViewer@, and record fields like @color@) are meant to
-- replace the raw ones at a call site, not sit next to them unqualified.
--
-- Each options record here covers more of Cesium's real field set than
-- the raw layer's hand-picked positional constructors do (see
-- "Cesium.Entity", "Cesium.Viewer"); every field is 'Maybe' - @Nothing@
-- omits the key, so Cesium's own default applies. Start from the
-- @defaultXOptions@ value and override just what you need:
--
-- > Simple.newViewer containerId Simple.defaultViewerOptions
-- >   { Simple.timeline = Just False
-- >   , Simple.animation = Just False
-- >   }
--
-- Coverage so far: 'ViewerOptions', 'PointOptions', 'LabelOptions'. More
-- options records get added the same way, as something needs them - the
-- pattern (record + @deriving Generic@ + empty @ToOptions@ instance +
-- a default value) is the same every time.
-----------------------------------------------------------------------------
module Cesium.Simple
  ( ViewerOptions(..)
  , defaultViewerOptions
  , newViewer
  , PointOptions(..)
  , defaultPointOptions
  , addPointEntity
  , LabelOptions(..)
  , defaultLabelOptions
  , addLabelEntity
  ) where
-----------------------------------------------------------------------------
import GHC.Generics (Generic)
import GHC.Wasm.Prim (JSString)

import Cesium.Core
import Cesium.Options
import Cesium.Math (Cartesian3, Color, unCartesian3)
import Cesium.Viewer (Viewer)
import Cesium.Entity (Entity)

import qualified Cesium.Viewer as Viewer
import qualified Cesium.Entity as Entity
-----------------------------------------------------------------------------
-- | The subset of @Cesium.Viewer@ constructor options that are just
-- booleans toggling a default UI widget on/off - by far the most common
-- thing people want to change from Cesium's defaults.
data ViewerOptions = ViewerOptions
  { timeline :: Maybe Bool
  , animation :: Maybe Bool
  , baseLayerPicker :: Maybe Bool
  , sceneModePicker :: Maybe Bool
  , geocoder :: Maybe Bool
  , homeButton :: Maybe Bool
  , navigationHelpButton :: Maybe Bool
  , infoBox :: Maybe Bool
  , selectionIndicator :: Maybe Bool
  , fullscreenButton :: Maybe Bool
  } deriving (Generic)

instance ToOptions ViewerOptions

defaultViewerOptions :: ViewerOptions
defaultViewerOptions = ViewerOptions
  { timeline = Nothing
  , animation = Nothing
  , baseLayerPicker = Nothing
  , sceneModePicker = Nothing
  , geocoder = Nothing
  , homeButton = Nothing
  , navigationHelpButton = Nothing
  , infoBox = Nothing
  , selectionIndicator = Nothing
  , fullscreenButton = Nothing
  }

newViewer :: JSString -> ViewerOptions -> IO Viewer
newViewer containerId opts = do
  o <- toOptions opts
  Viewer.newViewer containerId o
-----------------------------------------------------------------------------
-- | The common subset of @PointGraphics@ - see "Cesium.Entity" for the
-- raw, 2-field version this replaces.
data PointOptions = PointOptions
  { pixelSize :: Maybe Double
  , color :: Maybe Color
  , outlineColor :: Maybe Color
  , outlineWidth :: Maybe Double
  , show :: Maybe Bool
  } deriving (Generic)

instance ToOptions PointOptions

defaultPointOptions :: PointOptions
defaultPointOptions = PointOptions
  { pixelSize = Nothing
  , color = Nothing
  , outlineColor = Nothing
  , outlineWidth = Nothing
  , show = Nothing
  }

addPointEntity :: Viewer -> Cartesian3 -> PointOptions -> IO Entity
addPointEntity v pos opts = do
  point <- toOptions opts
  entityOpts <- newObject
  setProp entityOpts (str "position") (unCartesian3 pos)
  setProp entityOpts (str "point") point
  Entity.addEntity v entityOpts
-----------------------------------------------------------------------------
-- | The common subset of @LabelGraphics@ - see "Cesium.Entity" for the
-- raw, 2-field version this replaces.
data LabelOptions = LabelOptions
  { text :: Maybe String
  , font :: Maybe String
  , fillColor :: Maybe Color
  , outlineColor :: Maybe Color
  , showBackground :: Maybe Bool
  , scale :: Maybe Double
  } deriving (Generic)

instance ToOptions LabelOptions

defaultLabelOptions :: LabelOptions
defaultLabelOptions = LabelOptions
  { text = Nothing
  , font = Nothing
  , fillColor = Nothing
  , outlineColor = Nothing
  , showBackground = Nothing
  , scale = Nothing
  }

addLabelEntity :: Viewer -> Cartesian3 -> LabelOptions -> IO Entity
addLabelEntity v pos opts = do
  label <- toOptions opts
  entityOpts <- newObject
  setProp entityOpts (str "position") (unCartesian3 pos)
  setProp entityOpts (str "label") label
  Entity.addEntity v entityOpts
-----------------------------------------------------------------------------
