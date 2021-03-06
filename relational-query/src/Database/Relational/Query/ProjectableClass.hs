{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DefaultSignatures #-}

-- |
-- Module      : Database.Relational.Query.ProjectableClass
-- Copyright   : 2017 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module provides interfaces to preserve constraints of
-- direct product projections.
module Database.Relational.Query.ProjectableClass (
  -- * Interface to specify record constructors.
  ProductConstructor (..),

  -- * ProjectableFunctor and ProjectableApplicative
  ProjectableFunctor (..), ProjectableApplicative (..), ipfmap,

  -- * Literal SQL terms
  ShowConstantTermsSQL (..), showConstantTermsSQL,
  StringSQL,

  ) where

import GHC.Generics (Generic, Rep, U1 (..), K1 (..), M1 (..), (:*:)(..), from)
import Data.Monoid (mempty, (<>))
import Data.DList (DList, toList)

import Database.Relational.Query.Internal.SQL (StringSQL)


-- | Specify tuple like record constructors which are allowed to define 'ProjectableFunctor'.
class ProductConstructor r where
  -- | The constructor which has type 'r'.
  productConstructor :: r

-- | Weaken functor on projections.
class ProjectableFunctor p where
  -- | Method like 'fmap'.
  (|$|) :: ProductConstructor (a -> b) => (a -> b) -> p a -> p b

-- | Same as '|$|' other than using inferred record constructor.
ipfmap :: (ProjectableFunctor p, ProductConstructor (a -> b))
       => p a -> p b
ipfmap =  (|$|) productConstructor

-- | Weaken applicative functor on projections.
class ProjectableFunctor p => ProjectableApplicative p where
  -- | Method like '<*>'.
  (|*|) :: p (a -> b) -> p a -> p b

infixl 4 |$|, |*|


showConstantTermsSQL :: ShowConstantTermsSQL a
                     => a
                     -> [StringSQL]
showConstantTermsSQL = toList . showConstantTermsSQL'

-- | Interface for constant SQL term list.
class ShowConstantTermsSQL a where
  showConstantTermsSQL' :: a -> DList StringSQL

  default showConstantTermsSQL' :: (Generic a, GShowConstantTermsSQL (Rep a)) => a -> DList StringSQL
  showConstantTermsSQL' = gShowConstantTermsSQL . from

class GShowConstantTermsSQL f where
  gShowConstantTermsSQL :: f a -> DList StringSQL

instance GShowConstantTermsSQL U1 where
  gShowConstantTermsSQL U1 = mempty

instance (GShowConstantTermsSQL a, GShowConstantTermsSQL b) =>
         GShowConstantTermsSQL (a :*: b) where
  gShowConstantTermsSQL (a :*: b) = gShowConstantTermsSQL a <> gShowConstantTermsSQL b

instance GShowConstantTermsSQL a => GShowConstantTermsSQL (M1 i c a) where
  gShowConstantTermsSQL (M1 a) = gShowConstantTermsSQL a

instance ShowConstantTermsSQL a => GShowConstantTermsSQL (K1 i a) where
  gShowConstantTermsSQL (K1 a) = showConstantTermsSQL' a
