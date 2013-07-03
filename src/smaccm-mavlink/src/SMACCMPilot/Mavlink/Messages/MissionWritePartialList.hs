{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.MissionWritePartialList where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language

missionWritePartialListMsgId :: Uint8
missionWritePartialListMsgId = 38

missionWritePartialListCrcExtra :: Uint8
missionWritePartialListCrcExtra = 9

missionWritePartialListModule :: Module
missionWritePartialListModule = package "mavlink_mission_write_partial_list_msg" $ do
  depend packModule
  incl missionWritePartialListUnpack
  defStruct (Proxy :: Proxy "mission_write_partial_list_msg")

[ivory|
struct mission_write_partial_list_msg
  { start_index :: Stored Sint16
  ; end_index :: Stored Sint16
  ; target_system :: Stored Uint8
  ; target_component :: Stored Uint8
  }
|]

mkMissionWritePartialListSender :: SizedMavlinkSender 6
                       -> Def ('[ ConstRef s (Struct "mission_write_partial_list_msg") ] :-> ())
mkMissionWritePartialListSender sender =
  proc ("mavlink_mission_write_partial_list_msg_send" ++ (senderName sender)) $ \msg -> body $ do
    missionWritePartialListPack (senderMacro sender) msg

instance MavlinkSendable "mission_write_partial_list_msg" 6 where
  mkSender = mkMissionWritePartialListSender

missionWritePartialListPack :: (GetAlloc eff ~ Scope s, GetReturn eff ~ Returns ())
                  => SenderMacro eff s 6
                  -> ConstRef s1 (Struct "mission_write_partial_list_msg")
                  -> Ivory eff ()
missionWritePartialListPack sender msg = do
  arr <- local (iarray [] :: Init (Array 6 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> start_index)
  call_ pack buf 2 =<< deref (msg ~> end_index)
  call_ pack buf 4 =<< deref (msg ~> target_system)
  call_ pack buf 5 =<< deref (msg ~> target_component)
  sender missionWritePartialListMsgId (constRef arr) missionWritePartialListCrcExtra
  retVoid

instance MavlinkUnpackableMsg "mission_write_partial_list_msg" where
    unpackMsg = ( missionWritePartialListUnpack , missionWritePartialListMsgId )

missionWritePartialListUnpack :: Def ('[ Ref s1 (Struct "mission_write_partial_list_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
missionWritePartialListUnpack = proc "mavlink_mission_write_partial_list_unpack" $ \ msg buf -> body $ do
  store (msg ~> start_index) =<< call unpack buf 0
  store (msg ~> end_index) =<< call unpack buf 2
  store (msg ~> target_system) =<< call unpack buf 4
  store (msg ~> target_component) =<< call unpack buf 5

