{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DefaultSignatures #-}

-- |
-- Module      : Database.Record.Persistable
-- Copyright   : 2013-2017 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines interfaces
-- between Haskell type and list of SQL type.
module Database.Record.Persistable (
  -- * Specify SQL type
  PersistableSqlType, runPersistableNullValue, unsafePersistableSqlTypeFromNull,

  -- * Specify record width
  PersistableRecordWidth, runPersistableRecordWidth,
  unsafePersistableRecordWidth, unsafeValueWidth, (<&>), maybeWidth,

  -- * Inference rules for proof objects
  PersistableType(..), sqlNullValue,
  PersistableWidth (..), derivedWidth,

  -- * low-level interfaces
  GFieldWidthList,
  ProductConst, getProductConst,
  genericFieldOffsets,
  ) where

import GHC.Generics (Generic, Rep, U1 (..), K1 (..), M1 (..), (:*:)(..), to)
import Control.Applicative ((<$>), pure, (<*>), Const (..))
import Data.Monoid (Monoid, Sum (..))
import Data.Array (Array, listArray, bounds, (!))
import Data.DList (DList)
import qualified Data.DList as DList


-- | Proof object to specify type 'q' is SQL type
newtype PersistableSqlType q = PersistableSqlType q

-- | Null value of SQL type 'q'.
runPersistableNullValue :: PersistableSqlType q -> q
runPersistableNullValue (PersistableSqlType q) = q

-- | Unsafely generate 'PersistableSqlType' proof object from specified SQL null value which type is 'q'.
unsafePersistableSqlTypeFromNull :: q                    -- ^ SQL null value of SQL type 'q'
                                 -> PersistableSqlType q -- ^ Result proof object
unsafePersistableSqlTypeFromNull =  PersistableSqlType


-- | Restricted in product isomorphism record type b
newtype ProductConst a b =
  ProductConst { unPC :: Const a b }

-- | extract constant value of 'ProductConst'.
getProductConst :: ProductConst a b -> a
getProductConst = getConst . unPC
{-# INLINE getProductConst #-}

-- | Proof object to specify width of Haskell type 'a'
--   when converting to SQL type list.
type PersistableRecordWidth a = ProductConst (Sum Int) a

-- unsafely map PersistableRecordWidth
pmap :: Monoid e => (a -> b) -> ProductConst e a -> ProductConst e b
f `pmap` prw = ProductConst $ f <$> unPC prw

-- unsafely ap PersistableRecordWidth
pap :: Monoid e => ProductConst e (a -> b) -> ProductConst e a -> ProductConst e b
wf `pap` prw = ProductConst $ unPC wf <*> unPC prw


-- | Get width 'Int' value of record type 'a'.
runPersistableRecordWidth :: PersistableRecordWidth a -> Int
runPersistableRecordWidth = getSum . getConst . unPC
{-# INLINE runPersistableRecordWidth #-}

instance Show a => Show (ProductConst a b) where
  show = ("PC " ++) . show . getConst . unPC

-- | Unsafely generate 'PersistableRecordWidth' proof object from specified width of Haskell type 'a'.
unsafePersistableRecordWidth :: Int                      -- ^ Specify width of Haskell type 'a'
                             -> PersistableRecordWidth a -- ^ Result proof object
unsafePersistableRecordWidth = ProductConst . Const . Sum
{-# INLINE unsafePersistableRecordWidth #-}

-- | Unsafely generate 'PersistableRecordWidth' proof object for Haskell type 'a' which is single column type.
unsafeValueWidth :: PersistableRecordWidth a
unsafeValueWidth =  unsafePersistableRecordWidth 1
{-# INLINE unsafeValueWidth #-}

-- | Derivation rule of 'PersistableRecordWidth' for tuple (,) type.
(<&>) :: PersistableRecordWidth a -> PersistableRecordWidth b -> PersistableRecordWidth (a, b)
a <&> b = (,) `pmap` a `pap` b

-- | Derivation rule of 'PersistableRecordWidth' from from Haskell type 'a' into for Haskell type 'Maybe' 'a'.
maybeWidth :: PersistableRecordWidth a -> PersistableRecordWidth (Maybe a)
maybeWidth = pmap Just


-- | Interface of inference rule for 'PersistableSqlType' proof object
class Eq q => PersistableType q where
  persistableType :: PersistableSqlType q

-- | Inferred Null value of SQL type.
sqlNullValue :: PersistableType q => q
sqlNullValue =  runPersistableNullValue persistableType


-- | Interface of inference rule for 'PersistableRecordWidth' proof object
class PersistableWidth a where
  persistableWidth :: PersistableRecordWidth a

  default persistableWidth :: (Generic a, GFieldWidthList (Rep a)) => PersistableRecordWidth a
  persistableWidth = pmapConst (Sum . lastA) genericFieldOffsets
    where
      lastA a = a ! (snd $ bounds a)


pmapConst :: (a -> b) -> ProductConst a c -> ProductConst b c
pmapConst f = ProductConst . Const . f . getConst . unPC

-- | Generic width value list of record fields.
class GFieldWidthList f where
  gFieldWidthList :: ProductConst (DList Int) (f a)

instance GFieldWidthList U1 where
  gFieldWidthList = ProductConst $ pure U1

instance (GFieldWidthList a, GFieldWidthList b) => GFieldWidthList (a :*: b) where
  gFieldWidthList = (:*:) `pmap` gFieldWidthList `pap` gFieldWidthList

instance GFieldWidthList a => GFieldWidthList (M1 i c a) where
  gFieldWidthList = M1 `pmap` gFieldWidthList

instance PersistableWidth a => GFieldWidthList (K1 i a) where
  gFieldWidthList = K1 `pmap` pmapConst (pure . getSum) persistableWidth

offsets :: [Int] -> Array Int Int
offsets ws = listArray (0, length ws) $ scanl (+) 0 ws

-- | Generic offset array of record fields.
genericFieldOffsets :: (Generic a, GFieldWidthList (Rep a)) => ProductConst (Array Int Int) a
genericFieldOffsets = pmapConst (offsets . DList.toList) $ to `pmap` gFieldWidthList


-- | Inference rule of 'PersistableRecordWidth' proof object for 'Maybe' type.
instance PersistableWidth a => PersistableWidth (Maybe a) where
  persistableWidth = maybeWidth persistableWidth

-- | Inference rule of 'PersistableRecordWidth' for Haskell unit () type. Derive from axiom.
instance PersistableWidth ()  -- default generic instance

-- | Pass type parameter and inferred width value.
derivedWidth :: PersistableWidth a => (PersistableRecordWidth a, Int)
derivedWidth =  (pw, runPersistableRecordWidth pw) where
  pw = persistableWidth
