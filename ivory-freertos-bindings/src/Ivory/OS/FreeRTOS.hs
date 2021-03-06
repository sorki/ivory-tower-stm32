module Ivory.OS.FreeRTOS
  ( kernel
  , wrapper
  , objects
  , Config(..)
  , defaultConfig
  ) where

import System.FilePath
import qualified Paths_ivory_freertos_bindings as P
import Ivory.Artifact
import Ivory.OS.FreeRTOS.Config

kernel :: String -> Config -> [Located Artifact]
kernel core conf = configHeader conf : kas
  where
  kas = map loc (kernelfiles core)

wrapper :: [Located Artifact]
wrapper = map loc wrapperfiles

loc :: FilePath -> Located Artifact
loc f = l $ artifactCabalFile P.getDataDir f
  where
  l = case takeExtension f of
    ".h" -> Incl
    ".c" -> Src
    _ -> Root

wrapperfiles :: [FilePath]
wrapperfiles =
  [ "wrapper/freertos_atomic_wrapper.h"
  , "wrapper/freertos_atomic_wrapper.c"
  , "wrapper/freertos_semaphore_wrapper.h"
  , "wrapper/freertos_semaphore_wrapper.c"
  , "wrapper/freertos_mutex_wrapper.h"
  , "wrapper/freertos_mutex_wrapper.c"
  , "wrapper/freertos_task_wrapper.h"
  , "wrapper/freertos_task_wrapper.c"
  , "wrapper/freertos_time_wrapper.h"
  , "wrapper/freertos_time_wrapper.c"
  ]

kernelfiles :: String -> [FilePath]
kernelfiles core =
  [ "freertos-sources/list.c"
  , "freertos-sources/queue.c"
  , "freertos-sources/tasks.c"
  , "freertos-sources/timers.c"
  , "freertos-sources/include/FreeRTOS.h"
  , "freertos-sources/include/StackMacros.h"
  , "freertos-sources/include/list.h"
  , "freertos-sources/include/message_buffer.h"
  , "freertos-sources/include/mpu_wrappers.h"
  , "freertos-sources/include/mpu_prototypes.h"
  , "freertos-sources/include/portable.h"
  , "freertos-sources/include/projdefs.h"
  , "freertos-sources/include/queue.h"
  , "freertos-sources/include/semphr.h"
  , "freertos-sources/include/task.h"
  , "freertos-sources/include/timers.h"
  , "freertos-sources/include/stack_macros.h"
  , "freertos-sources/include/stream_buffer.h"
  , "freertos-sources/include/deprecated_definitions.h"
  , "freertos-sources/portable/GCC/ARM_" ++ core ++ "/port.c"
  , "freertos-sources/portable/GCC/ARM_" ++ core ++ "/portmacro.h"
  , "freertos-sources/portable/MemMang/heap_1.c"
  , "syscalls/assert.h"
  , "syscalls/syscalls.c"
  ]

objects :: String -> [FilePath]
objects core = map (\f -> replaceExtension f "o") (sources core)

sources :: String -> [FilePath]
sources core = filter (\f -> takeExtension f == ".c")
             $ map takeFileName ( wrapperfiles ++ (kernelfiles core) )

defaultConfig :: Config
defaultConfig  = Config
  { cpu_clock_hz       = 168 * 1000 * 1000
  , tick_rate_hz       = 1000
  , max_priorities     = 5
  , minimal_stack_size = 256
  , task_stack_size    = 2560
  , total_heap_size    = 64 * 1024
  }

