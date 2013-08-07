{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}

module Ivory.Tower.Compile.AADL.Modules (buildModules) where

import Ivory.Language
import Ivory.Tower.Types

buildModules :: Assembly -> [Module]
buildModules asm = ms
  where
  towerst = asm_towerst asm
  tasks   = asm_tasks   asm
  signals = asm_sigs    asm

  ms = tower_tasks
    ++ towerst_modules towerst
    ++ concatMap (taskst_extern_mods . nodest_impl . an_nodest) tasks

  nodeModules :: AssembledNode a -> [Module]
  nodeModules n = an_modules n systemDeps

  systemDeps :: ModuleDef
  systemDeps = do
    mapM_ depend (towerst_depends towerst)

  tower_tasks :: [Module]
  tower_tasks = concatMap nodeModules tasks ++ concatMap nodeModules signals


