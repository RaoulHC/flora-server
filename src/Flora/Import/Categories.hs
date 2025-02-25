module Flora.Import.Categories where

import Control.Monad.IO.Class
import Data.Text.IO qualified as T
import Effectful
import Effectful.PostgreSQL.Transact.Effect
import Flora.Import.Categories.Tuning as Tuning
import Flora.Model.Category.Types (Category, mkCategory, mkCategoryId)
import Flora.Model.Category.Update (insertCategory)

importCategories :: (DB :> es, IOE :> es) => Eff es ()
importCategories = do
  liftIO $! T.putStrLn "Sourcing categories from Datalog"
  canonicalCategories <- liftIO Tuning.sourceCategories
  categories <- mapM fromCanonical canonicalCategories
  mapM_ insertCategory categories

fromCanonical :: (IOE :> es) => CanonicalCategory -> Eff es Category
fromCanonical (CanonicalCategory slug name synopsis) = do
  categoryId <- liftIO mkCategoryId
  pure $! mkCategory categoryId name (Just slug) synopsis
