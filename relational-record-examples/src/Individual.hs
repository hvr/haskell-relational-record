{-# LANGUAGE TemplateHaskell, MultiParamTypeClasses, FlexibleInstances, DeriveGeneric #-}

module Individual where

import Database.Record.TH.SQLite3 (defineTable)

$(defineTable "examples.db" "individual")
