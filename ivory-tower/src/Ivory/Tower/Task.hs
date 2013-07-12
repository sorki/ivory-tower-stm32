{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}

module Ivory.Tower.Task where

import Text.Printf

import Ivory.Language

import Ivory.Tower.Types
import Ivory.Tower.Monad
import Ivory.Tower.Node

-- Public Task Definitions -----------------------------------------------------
instance Channelable TaskSt where
  nodeChannelEmitter  = taskChannelEmitter
  nodeChannelReceiver = taskChannelReceiver

taskChannelEmitter :: forall n area . (SingI n, IvoryArea area)
        => ChannelSource n area -> Node TaskSt (ChannelEmitter n area)
taskChannelEmitter chsrc = do
  nodename <- getNodeName
  unique   <- freshname -- May not be needed.
  let chid    = unChannelSource chsrc
      emitName = printf "emitFromTask_%s_chan%d%s" nodename (chan_id chid) unique
      externEmit :: Def ('[ConstRef s area] :-> IBool)
      externEmit = externProc emitName
      procEmit :: TaskSchedule -> Def ('[ConstRef s area] :-> IBool)
      procEmit schedule = proc emitName $ \ref -> body $ do
        r <- tsch_mkEmitter schedule emitter ref
        ret r
      emitter  = ChannelEmitter
        { ce_chid         = chid
        , ce_extern_emit  = call  externEmit
        , ce_extern_emit_ = call_ externEmit
        }
  taskStAddModuleDef $ \sch -> do
    incl (procEmit sch)
  return emitter

taskChannelReceiver :: forall n area
                     . (SingI n, IvoryArea area, IvoryZero area)
                    => ChannelSink n area
                    -> Node TaskSt (ChannelReceiver n area)
taskChannelReceiver chsnk = do
  nodename <- getNodeName
  unique   <- freshname -- May not be needed.
  let chid = unChannelSink chsnk
      rxName = printf "receiveFromTask_%s_chan%d%s" nodename (chan_id chid) unique
      externRx :: Def ('[Ref s area] :-> IBool)
      externRx = externProc rxName
      procRx :: TaskSchedule -> Def ('[Ref s area] :-> IBool)
      procRx schedule = proc rxName $ \ref -> body $ do
        r <- tsch_mkReceiver schedule rxer ref
        ret r
      rxer = ChannelReceiver
        { cr_chid      = chid
        , cr_extern_rx = call externRx
        }
  taskStAddModuleDef $ \sch -> do
    incl (procRx sch)
  return rxer

------

instance DataPortable TaskSt where
  nodeDataReader = taskDataReader
  nodeDataWriter = taskDataWriter

taskDataReader :: forall area . (IvoryArea area)
               => DataSink area -> Node TaskSt (DataReader area)
taskDataReader dsnk = do
  nodename <- getNodeName
  unique   <- freshname -- May not be needed.
  let dpid = unDataSink dsnk
      readerName = printf "read_%s_dataport%d%s" nodename (unDataportId dpid) unique
      externReader :: Def ('[Ref s area] :-> ())
      externReader = externProc readerName
      procReader :: TaskSchedule -> Def ('[Ref s area] :-> ())
      procReader schedule = proc readerName $ \ref -> body $
        tsch_mkDataReader schedule dsnk ref
      reader = DataReader
        { dr_dpid   = dpid
        , dr_extern = call_ externReader
        }
  taskStAddModuleDef $ \sch -> do
    incl (procReader sch)
  return reader

taskDataWriter :: forall area . (IvoryArea area)
               => DataSource area -> Node TaskSt (DataWriter area)
taskDataWriter dsrc = do
  nodename <- getNodeName
  unique   <- freshname -- May not be needed.
  let dpid = unDataSource dsrc
      writerName = printf "write_%s_dataport%d%s" nodename (unDataportId dpid) unique
      externWriter :: Def ('[ConstRef s area] :-> ())
      externWriter = externProc writerName
      procWriter :: TaskSchedule -> Def ('[ConstRef s area] :-> ())
      procWriter schedule = proc writerName $ \ref -> body $
        tsch_mkDataWriter schedule dsrc ref
      writer = DataWriter
        { dw_dpid   = dpid
        , dw_extern = call_ externWriter
        }
  taskStAddModuleDef $ \sch -> do
    incl (procWriter sch)
  return writer

-- | Track Ivory dependencies used by the 'Ivory.Tower.Tower.taskBody' created
--   in the 'Ivory.Tower.Types.Task' context.
taskModuleDef :: ModuleDef -> Task ()
taskModuleDef = taskStAddModuleDef . const

-- | Specify the stack size, in bytes, of the 'Ivory.Tower.Tower.taskBody'
--   created in the 'Ivory.Tower.Types.Task' context.
withStackSize :: Integer -> Task ()
withStackSize stacksize = do
  s <- getTaskSt
  case taskst_stacksize s of
    Nothing -> setTaskSt $ s { taskst_stacksize = Just stacksize }
    Just _  -> getNodeName >>= \name ->
               fail ("Cannot use withStackSize more than once in task named "
                  ++  name)

-- | Specify an OS priority level of the 'Ivory.Tower.Tower.taskBody' created in
--   the 'Ivory.Tower.Types.Task' context. Implementation at the backend
--   defined by the 'Ivory.Tower.Types.OS' implementation.
withPriority :: Integer -> Task ()
withPriority p = do
  s <- getTaskSt
  case taskst_priority s of
    Nothing -> setTaskSt $ s { taskst_priority = Just p }
    Just _  -> getNodeName >>= \name ->
               fail ("Cannot use withPriority more than once in task named "
                     ++ name)

-- | Add an Ivory Module to the result of this Tower compilation, from the
--   Task context.
withModule :: Module -> Task ()
withModule m = do
  s <- getTaskSt
  setTaskSt $ s { taskst_extern_mods = m:(taskst_extern_mods s)}

-- | Create a 'Period' in the context of a 'Task'. Integer argument
--   declares period in milliseconds.
withPeriod :: Integer -> Task Period
withPeriod per = do
  st <- getTaskSt
  setTaskSt $ st { taskst_periods = per : (taskst_periods st)}
  os <- getOS
  n <- freshname
  let (p, initdef, mdef) = os_mkPeriodic os per n
  nodeStAddCodegen initdef mdef
  return p

-- | Create an 'Ivory.Tower.Types.OSGetTimeMillis' in the context of a 'Task'.
withGetTimeMillis :: Task OSGetTimeMillis
withGetTimeMillis = do
  os <- getOS
  return $ OSGetTimeMillis (os_getTimeMillis os)

taskLocal :: (IvoryArea area) => Name -> Task (Ref Global area)
taskLocal n = tlocalAux n Nothing

taskLocalInit :: (IvoryArea area) => Name -> Init area -> Task (Ref Global area)
taskLocalInit n i = tlocalAux n (Just i)

tlocalAux :: (IvoryArea area) => Name -> Maybe (Init area) -> Task (Ref Global area)
tlocalAux n i = do
  f <- freshname
  let m = area (n ++ f) i
  taskStAddModuleDef (const (defMemArea m))
  return (addrOf m)

taskInit :: ( forall s . Ivory (ProcEffects s ()) () ) -> Task ()
taskInit i = do
  s <- getTaskSt
  n <- getNodeName
  case taskst_taskinit s of
    Nothing -> setTaskSt $ s { taskst_taskinit = Just (initproc n) }
    Just _ -> (err n)
  where
  err nodename = error ("multiple taskInit definitions in task named "
                          ++ nodename)
  initproc nodename = proc ("taskInit_" ++ nodename) $ body i

onChannel :: ChannelReceiver n area
          -> (forall s s' . ConstRef s area -> Ivory (ProcEffects s' ()) ())
          -> Task ()
onChannel chrxer k = taskStAddTaskHandler $ TH_Channel handler
  where
  handler = ChannelHandler { ch_receiver = cr_extern_rx chrxer
                           , ch_callback = k }

onPeriod :: Period -> (forall s  . Uint32 -> Ivory (ProcEffects s ()) ()) -> Task ()
onPeriod per k = taskStAddTaskHandler $ TH_Period handler
  where
  handler = PeriodHandler { ph_period = per
                          , ph_callback =  k
                          }

