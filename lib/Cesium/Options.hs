-----------------------------------------------------------------------------
{-# LANGUAGE DefaultSignatures    #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}
-----------------------------------------------------------------------------
-- |
-- Generic machinery behind "Cesium.Simple": turn a plain Haskell record
-- into a Cesium JS options object automatically, instead of hand-writing
-- a 'Cesium.Core.setProp' call for every field.
--
-- Define a record with fields named exactly like the Cesium option you're
-- targeting (Cesium's own naming is already camelCase, so this is usually
-- a direct copy from their docs), wrap every field in 'Maybe' (@Nothing@
-- means "omit the key, let Cesium use its own default"), derive
-- 'GHC.Generics.Generic', and write @instance ToOptions MyOptions@ with no
-- body - 'toOptions' defaults to the generic implementation, driven by
-- the record's field names.
--
-- Only handles flat option bags: a field whose Cesium value is itself a
-- nested object (e.g. @orientation: { heading, pitch, roll }@, as in
-- 'Cesium.Viewer.setView') needs its own 'ToOptionValue' instance (which
-- can itself build on 'toOptions), or a manual case - same as today.
-----------------------------------------------------------------------------
module Cesium.Options
  ( ToOptions(..)
  , ToOptionValue(..)
  ) where
-----------------------------------------------------------------------------
import GHC.Generics

import Cesium.Core
import Cesium.Math (Cartesian3, Color, unCartesian3, unColor)
-----------------------------------------------------------------------------
-- | A record that can become a Cesium options object.
class ToOptions a where
  toOptions :: a -> IO JSVal
  default toOptions :: (Generic a, GToOptions (Rep a)) => a -> IO JSVal
  toOptions x = do
    o <- newObject
    gToOptions o (from x)
    pure o
-----------------------------------------------------------------------------
class GToOptions f where
  gToOptions :: JSVal -> f p -> IO ()

instance (GToOptions f, GToOptions g) => GToOptions (f :*: g) where
  gToOptions o (a :*: b) = gToOptions o a >> gToOptions o b

instance GToOptions f => GToOptions (M1 D c f) where
  gToOptions o (M1 x) = gToOptions o x

instance GToOptions f => GToOptions (M1 C c f) where
  gToOptions o (M1 x) = gToOptions o x

-- | The one case that actually does something: a single field, tagged
-- with its record selector name via 'selName'.
instance (Selector s, ToOptionValue a) => GToOptions (M1 S s (K1 i a)) where
  gToOptions o m1@(M1 (K1 x)) = setOptionValue o (str (selName m1)) x
-----------------------------------------------------------------------------
-- | How to marshal one record field's value onto the options object.
class ToOptionValue a where
  setOptionValue :: JSVal -> JSString -> a -> IO ()

-- | 'Nothing' skips the field entirely, leaving Cesium's own default.
instance ToOptionValue a => ToOptionValue (Maybe a) where
  setOptionValue _ _ Nothing = pure ()
  setOptionValue o k (Just x) = setOptionValue o k x

instance ToOptionValue Double where
  setOptionValue = setPropNum

instance ToOptionValue Bool where
  setOptionValue = setPropBool

instance ToOptionValue String where
  setOptionValue o k s = setPropStr o k (str s)

instance ToOptionValue Color where
  setOptionValue o k c = setProp o k (unColor c)

instance ToOptionValue Cartesian3 where
  setOptionValue o k c = setProp o k (unCartesian3 c)

-- | Escape hatch: an already-built raw value (e.g. from another
-- 'ToOptions' record, or hand-assembled with "Cesium.Core").
instance ToOptionValue JSVal where
  setOptionValue = setProp
-----------------------------------------------------------------------------
