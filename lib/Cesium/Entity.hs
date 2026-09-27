-----------------------------------------------------------------------------
-- |
-- Phase 4 of the checklist: the Entity API - @viewer.entities.add@ and the
-- handful of graphics types (point, label, billboard, polyline, polygon).
--
-- Cesium's entity options object can carry arbitrarily many graphics types
-- and properties; rather than model all of it, each @addXEntity@ here
-- covers the common positional-argument case for one graphics type. Drop
-- to 'addEntity' with your own "Cesium.Core"-built options object for
-- anything these don't cover (e.g. combining several graphics on one
-- entity, or fields these convenience functions don't expose).
--
-- Not yet bound: @RectangleGraphics@, @EllipseGraphics@, @ModelGraphics@ -
-- same pattern, added when something needs them.
-----------------------------------------------------------------------------
module Cesium.Entity
  ( Entity
  , unEntity
  , addEntity
  , removeEntity
  , removeAllEntities
  , addPointEntity
  , addLabelEntity
  , addBillboardEntity
  , addPolylineEntity
  , addPolygonEntity
  ) where
-----------------------------------------------------------------------------
import GHC.Wasm.Prim

import Cesium.Core
import Cesium.Math (Cartesian3, Color, unCartesian3, unColor)
import Cesium.Viewer (Viewer, unViewer)
-----------------------------------------------------------------------------
-- | An opaque handle to a JS @Cesium.Entity@ instance.
newtype Entity = Entity JSVal

-- | Escape hatch for other "Cesium.*" modules (e.g. picking) that need the
-- underlying entity object for a raw FFI import.
unEntity :: Entity -> JSVal
unEntity (Entity e) = e
-----------------------------------------------------------------------------
foreign import javascript unsafe "return $1.entities.add($2)"
  js_addEntity :: JSVal -> JSVal -> IO JSVal

-- | Add an entity built from a raw options object (see "Cesium.Core").
addEntity :: Viewer -> JSVal -> IO Entity
addEntity v opts = Entity <$> js_addEntity (unViewer v) opts
-----------------------------------------------------------------------------
foreign import javascript unsafe "return $1.entities.remove($2)"
  js_removeEntity :: JSVal -> JSVal -> IO Bool

removeEntity :: Viewer -> Entity -> IO Bool
removeEntity v (Entity e) = js_removeEntity (unViewer v) e
-----------------------------------------------------------------------------
foreign import javascript unsafe "$1.entities.removeAll()"
  js_removeAllEntities :: JSVal -> IO ()

removeAllEntities :: Viewer -> IO ()
removeAllEntities v = js_removeAllEntities (unViewer v)
-----------------------------------------------------------------------------
-- | A JS array of 'Cartesian3' positions, for polyline\/polygon graphics.
cartesian3Array :: [Cartesian3] -> IO JSVal
cartesian3Array positions = do
  arr <- newArray
  mapM_ (arrayPush arr . unCartesian3) positions
  pure arr
-----------------------------------------------------------------------------
-- | A point marker at a fixed position.
addPointEntity :: Viewer -> Cartesian3 -> Double -> Color -> IO Entity
addPointEntity v pos pixelSize color = do
  point <- newObject
  setPropNum point (str "pixelSize") pixelSize
  setProp point (str "color") (unColor color)
  opts <- newObject
  setProp opts (str "position") (unCartesian3 pos)
  setProp opts (str "point") point
  addEntity v opts
-----------------------------------------------------------------------------
-- | A text label at a fixed position.
addLabelEntity :: Viewer -> Cartesian3 -> String -> IO Entity
addLabelEntity v pos txt = do
  label <- newObject
  setPropStr label (str "text") (str txt)
  opts <- newObject
  setProp opts (str "position") (unCartesian3 pos)
  setProp opts (str "label") label
  addEntity v opts
-----------------------------------------------------------------------------
-- | An image billboard at a fixed position.
addBillboardEntity :: Viewer -> Cartesian3 -> String -> IO Entity
addBillboardEntity v pos imageUrl = do
  billboard <- newObject
  setPropStr billboard (str "image") (str imageUrl)
  opts <- newObject
  setProp opts (str "position") (unCartesian3 pos)
  setProp opts (str "billboard") billboard
  addEntity v opts
-----------------------------------------------------------------------------
-- | A line strip through the given positions.
addPolylineEntity :: Viewer -> [Cartesian3] -> Double -> Color -> IO Entity
addPolylineEntity v positions width color = do
  posArr <- cartesian3Array positions
  polyline <- newObject
  setProp polyline (str "positions") posArr
  setPropNum polyline (str "width") width
  setProp polyline (str "material") (unColor color)
  opts <- newObject
  setProp opts (str "polyline") polyline
  addEntity v opts
-----------------------------------------------------------------------------
-- | A filled polygon over the given positions.
addPolygonEntity :: Viewer -> [Cartesian3] -> Color -> IO Entity
addPolygonEntity v positions color = do
  posArr <- cartesian3Array positions
  polygon <- newObject
  setProp polygon (str "hierarchy") posArr
  setProp polygon (str "material") (unColor color)
  opts <- newObject
  setProp opts (str "polygon") polygon
  addEntity v opts
-----------------------------------------------------------------------------
