{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- |
-- Module      : Database.Relational.Query.Monad.Aggregate
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module contains definitions about aggregated query type.
module Database.Relational.Query.Monad.Aggregate (
  -- * Aggregated Query
  QueryAggregate,
  AggregatedQuery,

  toSQL,

  toSubQuery
  ) where

import Database.Relational.Query.Context (Flat, Aggregated)
import Database.Relational.Query.Projection (Projection)
import qualified Database.Relational.Query.Projection as Projection
import Database.Relational.Query.SQL (selectSeedSQL)
import Database.Relational.Query.Sub (SubQuery, subQuery)

import Database.Relational.Query.Monad.Qualify (Qualify)
import Database.Relational.Query.Monad.Class (MonadQualify(..))
import Database.Relational.Query.Monad.Trans.Join
  (join', FromPrepend, prependFrom, extractFrom)
import Database.Relational.Query.Monad.Trans.Restricting
  (restrictings, WherePrepend, prependWhere, extractWheres)
import Database.Relational.Query.Monad.Trans.Aggregating
  (Aggregatings, aggregatings, GroupBysPrepend, prependGroupBys, extractGroupBys)
import Database.Relational.Query.Monad.Trans.Ordering
  (Orderings, orderings, OrderedQuery, OrderByPrepend, prependOrderBy, extractOrderBys)
import Database.Relational.Query.Monad.Type (QueryCore)


-- | Aggregated query monad type.
type QueryAggregate    = Orderings Aggregated (Aggregatings QueryCore)

-- | Aggregated query type. AggregatedQuery r == QueryAggregate (Projection Aggregated r).
type AggregatedQuery r = OrderedQuery Aggregated (Aggregatings QueryCore) r

-- | Lift from qualified table forms into 'QueryAggregate'.
aggregatedQuery :: Qualify a -> QueryAggregate a
aggregatedQuery =  orderings . aggregatings . restrictings . join'

-- | Instance to lift from qualified table forms into 'QueryAggregate'.
instance MonadQualify Qualify (Orderings Aggregated (Aggregatings QueryCore)) where
  liftQualify = aggregatedQuery

expandPrepend :: AggregatedQuery r
                 -> Qualify ((((Projection Aggregated r, OrderByPrepend), GroupBysPrepend), WherePrepend), FromPrepend)
expandPrepend =  extractFrom . extractWheres . extractGroupBys . extractOrderBys

-- | Run 'AggregatedQuery' to get SQL string.
expandSQL :: AggregatedQuery r -> Qualify (String, Projection Flat r)
expandSQL q = do
  ((((aggr, ao), ag), aw), af) <- expandPrepend q
  let projection = Projection.unsafeToFlat aggr
  return (selectSeedSQL projection . prependFrom af . prependWhere aw
          . prependGroupBys ag . prependOrderBy ao $ "",
          projection)

-- | Run 'AggregatedQuery' to get SQL with 'Qualify' computation.
toSQL :: AggregatedQuery r -- ^ 'AggregatedQuery' to run
      -> Qualify String    -- ^ Result SQL string with 'Qualify' computation
toSQL =  fmap fst . expandSQL

-- | Run 'AggregatedQuery' to get 'SubQuery' with 'Qualify' computation.
toSubQuery :: AggregatedQuery r -- ^ 'AggregatedQuery' to run
           -> Qualify SubQuery  -- ^ Result 'SubQuery' with 'Qualify' computation
toSubQuery q = do
  (sql, pj) <- expandSQL q
  return $ subQuery sql (Projection.width pj)
