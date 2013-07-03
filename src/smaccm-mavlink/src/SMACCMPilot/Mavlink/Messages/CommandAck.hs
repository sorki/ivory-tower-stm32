{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.CommandAck where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language

commandAckMsgId :: Uint8
commandAckMsgId = 77

commandAckCrcExtra :: Uint8
commandAckCrcExtra = 143

commandAckModule :: Module
commandAckModule = package "mavlink_command_ack_msg" $ do
  depend packModule
  incl commandAckUnpack
  defStruct (Proxy :: Proxy "command_ack_msg")

[ivory|
struct command_ack_msg
  { command :: Stored Uint16
  ; result :: Stored Uint8
  }
|]

mkCommandAckSender :: SizedMavlinkSender 3
                       -> Def ('[ ConstRef s (Struct "command_ack_msg") ] :-> ())
mkCommandAckSender sender =
  proc ("mavlink_command_ack_msg_send" ++ (senderName sender)) $ \msg -> body $ do
    commandAckPack (senderMacro sender) msg

instance MavlinkSendable "command_ack_msg" 3 where
  mkSender = mkCommandAckSender

commandAckPack :: (GetAlloc eff ~ Scope s, GetReturn eff ~ Returns ())
                  => SenderMacro eff s 3
                  -> ConstRef s1 (Struct "command_ack_msg")
                  -> Ivory eff ()
commandAckPack sender msg = do
  arr <- local (iarray [] :: Init (Array 3 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> command)
  call_ pack buf 2 =<< deref (msg ~> result)
  sender commandAckMsgId (constRef arr) commandAckCrcExtra
  retVoid

instance MavlinkUnpackableMsg "command_ack_msg" where
    unpackMsg = ( commandAckUnpack , commandAckMsgId )

commandAckUnpack :: Def ('[ Ref s1 (Struct "command_ack_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
commandAckUnpack = proc "mavlink_command_ack_unpack" $ \ msg buf -> body $ do
  store (msg ~> command) =<< call unpack buf 0
  store (msg ~> result) =<< call unpack buf 2

