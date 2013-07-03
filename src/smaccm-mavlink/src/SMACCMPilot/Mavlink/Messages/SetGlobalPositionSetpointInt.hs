{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.SetGlobalPositionSetpointInt where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language

setGlobalPositionSetpointIntMsgId :: Uint8
setGlobalPositionSetpointIntMsgId = 53

setGlobalPositionSetpointIntCrcExtra :: Uint8
setGlobalPositionSetpointIntCrcExtra = 33

setGlobalPositionSetpointIntModule :: Module
setGlobalPositionSetpointIntModule = package "mavlink_set_global_position_setpoint_int_msg" $ do
  depend packModule
  incl setGlobalPositionSetpointIntUnpack
  defStruct (Proxy :: Proxy "set_global_position_setpoint_int_msg")

[ivory|
struct set_global_position_setpoint_int_msg
  { latitude :: Stored Sint32
  ; longitude :: Stored Sint32
  ; altitude :: Stored Sint32
  ; yaw :: Stored Sint16
  ; coordinate_frame :: Stored Uint8
  }
|]

mkSetGlobalPositionSetpointIntSender :: SizedMavlinkSender 15
                       -> Def ('[ ConstRef s (Struct "set_global_position_setpoint_int_msg") ] :-> ())
mkSetGlobalPositionSetpointIntSender sender =
  proc ("mavlink_set_global_position_setpoint_int_msg_send" ++ (senderName sender)) $ \msg -> body $ do
    setGlobalPositionSetpointIntPack (senderMacro sender) msg

instance MavlinkSendable "set_global_position_setpoint_int_msg" 15 where
  mkSender = mkSetGlobalPositionSetpointIntSender

setGlobalPositionSetpointIntPack :: (GetAlloc eff ~ Scope s, GetReturn eff ~ Returns ())
                  => SenderMacro eff s 15
                  -> ConstRef s1 (Struct "set_global_position_setpoint_int_msg")
                  -> Ivory eff ()
setGlobalPositionSetpointIntPack sender msg = do
  arr <- local (iarray [] :: Init (Array 15 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> latitude)
  call_ pack buf 4 =<< deref (msg ~> longitude)
  call_ pack buf 8 =<< deref (msg ~> altitude)
  call_ pack buf 12 =<< deref (msg ~> yaw)
  call_ pack buf 14 =<< deref (msg ~> coordinate_frame)
  sender setGlobalPositionSetpointIntMsgId (constRef arr) setGlobalPositionSetpointIntCrcExtra
  retVoid

instance MavlinkUnpackableMsg "set_global_position_setpoint_int_msg" where
    unpackMsg = ( setGlobalPositionSetpointIntUnpack , setGlobalPositionSetpointIntMsgId )

setGlobalPositionSetpointIntUnpack :: Def ('[ Ref s1 (Struct "set_global_position_setpoint_int_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
setGlobalPositionSetpointIntUnpack = proc "mavlink_set_global_position_setpoint_int_unpack" $ \ msg buf -> body $ do
  store (msg ~> latitude) =<< call unpack buf 0
  store (msg ~> longitude) =<< call unpack buf 4
  store (msg ~> altitude) =<< call unpack buf 8
  store (msg ~> yaw) =<< call unpack buf 12
  store (msg ~> coordinate_frame) =<< call unpack buf 14

