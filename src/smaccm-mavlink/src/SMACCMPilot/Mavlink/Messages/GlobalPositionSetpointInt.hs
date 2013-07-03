{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.GlobalPositionSetpointInt where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language

globalPositionSetpointIntMsgId :: Uint8
globalPositionSetpointIntMsgId = 52

globalPositionSetpointIntCrcExtra :: Uint8
globalPositionSetpointIntCrcExtra = 141

globalPositionSetpointIntModule :: Module
globalPositionSetpointIntModule = package "mavlink_global_position_setpoint_int_msg" $ do
  depend packModule
  incl globalPositionSetpointIntUnpack
  defStruct (Proxy :: Proxy "global_position_setpoint_int_msg")

[ivory|
struct global_position_setpoint_int_msg
  { latitude :: Stored Sint32
  ; longitude :: Stored Sint32
  ; altitude :: Stored Sint32
  ; yaw :: Stored Sint16
  ; coordinate_frame :: Stored Uint8
  }
|]

mkGlobalPositionSetpointIntSender :: SizedMavlinkSender 15
                       -> Def ('[ ConstRef s (Struct "global_position_setpoint_int_msg") ] :-> ())
mkGlobalPositionSetpointIntSender sender =
  proc ("mavlink_global_position_setpoint_int_msg_send" ++ (senderName sender)) $ \msg -> body $ do
    globalPositionSetpointIntPack (senderMacro sender) msg

instance MavlinkSendable "global_position_setpoint_int_msg" 15 where
  mkSender = mkGlobalPositionSetpointIntSender

globalPositionSetpointIntPack :: (GetAlloc eff ~ Scope s, GetReturn eff ~ Returns ())
                  => SenderMacro eff s 15
                  -> ConstRef s1 (Struct "global_position_setpoint_int_msg")
                  -> Ivory eff ()
globalPositionSetpointIntPack sender msg = do
  arr <- local (iarray [] :: Init (Array 15 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> latitude)
  call_ pack buf 4 =<< deref (msg ~> longitude)
  call_ pack buf 8 =<< deref (msg ~> altitude)
  call_ pack buf 12 =<< deref (msg ~> yaw)
  call_ pack buf 14 =<< deref (msg ~> coordinate_frame)
  sender globalPositionSetpointIntMsgId (constRef arr) globalPositionSetpointIntCrcExtra
  retVoid

instance MavlinkUnpackableMsg "global_position_setpoint_int_msg" where
    unpackMsg = ( globalPositionSetpointIntUnpack , globalPositionSetpointIntMsgId )

globalPositionSetpointIntUnpack :: Def ('[ Ref s1 (Struct "global_position_setpoint_int_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
globalPositionSetpointIntUnpack = proc "mavlink_global_position_setpoint_int_unpack" $ \ msg buf -> body $ do
  store (msg ~> latitude) =<< call unpack buf 0
  store (msg ~> longitude) =<< call unpack buf 4
  store (msg ~> altitude) =<< call unpack buf 8
  store (msg ~> yaw) =<< call unpack buf 12
  store (msg ~> coordinate_frame) =<< call unpack buf 14

