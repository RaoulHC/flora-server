{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE QuasiQuotes #-}

module Flora.Model.Release.Query
  ( getReleases
  , getReleaseByVersion
  , getPackageReleases
  , getPackageReleasesWithoutReadme
  , getPackageReleasesWithoutChangelog
  , getPackageReleasesWithoutUploadTimestamp
  , getAllReleases
  , getNumberOfReleases
  , getReleaseComponents
  )
where

import Data.Vector (Vector)
import Data.Vector qualified as Vector
import Data.Vector.Algorithms.Intro as MVector
import Database.PostgreSQL.Entity
import Database.PostgreSQL.Entity.DBT (QueryNature (..), query, queryOne)
import Database.PostgreSQL.Entity.Types (field)
import Database.PostgreSQL.Simple (Only (..), Query)
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Distribution.Version (Version)
import Effectful
import Effectful.PostgreSQL.Transact.Effect (DB, dbtToEff)
import Flora.Model.Package.Component
import Flora.Model.Package.Types
import Flora.Model.Release.Types

packageReleasesQuery :: Query
packageReleasesQuery = _selectWhere @Release [[field| package_id |]]

getReleases :: (DB :> es) => PackageId -> Eff es (Vector Release)
getReleases pid =
  dbtToEff $! do
    results <- query Select packageReleasesQuery (Only pid)
    if Vector.null results
      then pure results
      else pure $! Vector.take 6 $! Vector.reverse $! Vector.modify MVector.sort results

getAllReleases :: (DB :> es) => PackageId -> Eff es (Vector Release)
getAllReleases pid =
  dbtToEff $! do
    results <- query Select packageReleasesQuery (Only pid)
    if Vector.null results
      then pure results
      else pure $! Vector.reverse $! Vector.modify MVector.sort results

getPackageReleases :: (DB :> es) => Eff es (Vector (ReleaseId, Version, PackageName))
getPackageReleases =
  dbtToEff $
    query Select querySpec ()
  where
    querySpec :: Query
    querySpec =
      [sql|
        select r.release_id, r.version, p."name"
        from releases as r
        join packages as p
        on p.package_id = r.package_id
      |]

getPackageReleasesWithoutReadme :: (DB :> es) => Eff es (Vector (ReleaseId, Version, PackageName))
getPackageReleasesWithoutReadme =
  dbtToEff $
    query Select querySpec ()
  where
    querySpec :: Query
    querySpec =
      [sql|
        select r.release_id, r.version, p."name"
        from releases as r
        join packages as p
        on p.package_id = r.package_id
        where r.readme_status = 'not-imported'
      |]

getPackageReleasesWithoutUploadTimestamp :: (DB :> es) => Eff es (Vector (ReleaseId, Version, PackageName))
getPackageReleasesWithoutUploadTimestamp =
  dbtToEff $
    query Select querySpec ()
  where
    querySpec :: Query
    querySpec =
      [sql|
        select r.release_id, r.version, p."name"
        from releases as r
        join packages as p
        on p.package_id = r.package_id
        where r.uploaded_at is null
      |]

getPackageReleasesWithoutChangelog :: (DB :> es) => Eff es (Vector (ReleaseId, Version, PackageName))
getPackageReleasesWithoutChangelog =
  dbtToEff $
    query Select querySpec ()
  where
    querySpec :: Query
    querySpec =
      [sql|
        select r.release_id, r.version, p."name"
        from releases as r
        join packages as p
        on p.package_id = r.package_id
        where r.changelog_status = 'not-imported'
      |]

getReleaseByVersion :: (DB :> es) => PackageId -> Version -> Eff es (Maybe Release)
getReleaseByVersion packageId version = dbtToEff $! queryOne Select (_selectWhere @Release [[field| package_id |], [field| version |]]) (packageId, version)

getNumberOfReleases :: (DB :> es) => PackageId -> Eff es Word
getNumberOfReleases pid =
  dbtToEff $! do
    (result :: Maybe (Only Int)) <- queryOne Select numberOfReleasesQuery (Only pid)
    case result of
      Just (Only n) -> pure $! fromIntegral n
      Nothing -> pure 0

numberOfReleasesQuery :: Query
numberOfReleasesQuery =
  [sql|
  SELECT DISTINCT COUNT(rel."package_id")
  FROM releases AS rel
  WHERE rel."package_id" = ?
  |]

getReleaseComponents :: (DB :> es) => ReleaseId -> Eff es (Vector PackageComponent)
getReleaseComponents releaseId =
  dbtToEff $! query Select (_selectWhere @PackageComponent [[field| release_id |]]) (Only releaseId)
