{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.RollPitchYawThrustSetpoint where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

rollPitchYawThrustSetpointMsgId :: Uint8
rollPitchYawThrustSetpointMsgId = 58

rollPitchYawThrustSetpointCrcExtra :: Uint8
rollPitchYawThrustSetpointCrcExtra = 239

rollPitchYawThrustSetpointModule :: Module
rollPitchYawThrustSetpointModule = package "mavlink_roll_pitch_yaw_thrust_setpoint_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkRollPitchYawThrustSetpointSender
  incl rollPitchYawThrustSetpointUnpack
  defStruct (Proxy :: Proxy "roll_pitch_yaw_thrust_setpoint_msg")

[ivory|
struct roll_pitch_yaw_thrust_setpoint_msg
  { time_boot_ms :: Stored Uint32
  ; roll :: Stored IFloat
  ; pitch :: Stored IFloat
  ; yaw :: Stored IFloat
  ; thrust :: Stored IFloat
  }
|]

mkRollPitchYawThrustSetpointSender ::
  Def ('[ ConstRef s0 (Struct "roll_pitch_yaw_thrust_setpoint_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 (Array 128 (Stored Uint8)) -- tx buffer
        ] :-> ())
mkRollPitchYawThrustSetpointSender =
  proc "mavlink_roll_pitch_yaw_thrust_setpoint_msg_send"
  $ \msg seqNum sendArr -> body
  $ do
  arr <- local (iarray [] :: Init (Array 20 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> time_boot_ms)
  call_ pack buf 4 =<< deref (msg ~> roll)
  call_ pack buf 8 =<< deref (msg ~> pitch)
  call_ pack buf 12 =<< deref (msg ~> yaw)
  call_ pack buf 16 =<< deref (msg ~> thrust)
  -- 6: header len, 2: CRC len
  if arrayLen sendArr < 6 + 20 + 2
    then error "rollPitchYawThrustSetpoint payload is too large for 20 sender!"
    else do -- Copy, leaving room for the payload
            _ <- arrCopy sendArr arr 6
            call_ mavlinkSendWithWriter
                    rollPitchYawThrustSetpointMsgId
                    rollPitchYawThrustSetpointCrcExtra
                    20
                    seqNum
                    sendArr
            retVoid

instance MavlinkUnpackableMsg "roll_pitch_yaw_thrust_setpoint_msg" where
    unpackMsg = ( rollPitchYawThrustSetpointUnpack , rollPitchYawThrustSetpointMsgId )

rollPitchYawThrustSetpointUnpack :: Def ('[ Ref s1 (Struct "roll_pitch_yaw_thrust_setpoint_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
rollPitchYawThrustSetpointUnpack = proc "mavlink_roll_pitch_yaw_thrust_setpoint_unpack" $ \ msg buf -> body $ do
  store (msg ~> time_boot_ms) =<< call unpack buf 0
  store (msg ~> roll) =<< call unpack buf 4
  store (msg ~> pitch) =<< call unpack buf 8
  store (msg ~> yaw) =<< call unpack buf 12
  store (msg ~> thrust) =<< call unpack buf 16

