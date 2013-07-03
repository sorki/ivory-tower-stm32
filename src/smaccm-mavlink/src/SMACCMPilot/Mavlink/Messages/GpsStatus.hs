{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.GpsStatus where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language

gpsStatusMsgId :: Uint8
gpsStatusMsgId = 25

gpsStatusCrcExtra :: Uint8
gpsStatusCrcExtra = 23

gpsStatusModule :: Module
gpsStatusModule = package "mavlink_gps_status_msg" $ do
  depend packModule
  incl gpsStatusUnpack
  defStruct (Proxy :: Proxy "gps_status_msg")

[ivory|
struct gps_status_msg
  { satellites_visible :: Stored Uint8
  ; satellite_prn :: Array 20 (Stored Uint8)
  ; satellite_used :: Array 20 (Stored Uint8)
  ; satellite_elevation :: Array 20 (Stored Uint8)
  ; satellite_azimuth :: Array 20 (Stored Uint8)
  ; satellite_snr :: Array 20 (Stored Uint8)
  }
|]

mkGpsStatusSender :: SizedMavlinkSender 101
                       -> Def ('[ ConstRef s (Struct "gps_status_msg") ] :-> ())
mkGpsStatusSender sender =
  proc ("mavlink_gps_status_msg_send" ++ (senderName sender)) $ \msg -> body $ do
    gpsStatusPack (senderMacro sender) msg

instance MavlinkSendable "gps_status_msg" 101 where
  mkSender = mkGpsStatusSender

gpsStatusPack :: (GetAlloc eff ~ Scope s, GetReturn eff ~ Returns ())
                  => SenderMacro eff s 101
                  -> ConstRef s1 (Struct "gps_status_msg")
                  -> Ivory eff ()
gpsStatusPack sender msg = do
  arr <- local (iarray [] :: Init (Array 101 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> satellites_visible)
  arrayPack buf 1 (msg ~> satellite_prn)
  arrayPack buf 21 (msg ~> satellite_used)
  arrayPack buf 41 (msg ~> satellite_elevation)
  arrayPack buf 61 (msg ~> satellite_azimuth)
  arrayPack buf 81 (msg ~> satellite_snr)
  sender gpsStatusMsgId (constRef arr) gpsStatusCrcExtra
  retVoid

instance MavlinkUnpackableMsg "gps_status_msg" where
    unpackMsg = ( gpsStatusUnpack , gpsStatusMsgId )

gpsStatusUnpack :: Def ('[ Ref s1 (Struct "gps_status_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
gpsStatusUnpack = proc "mavlink_gps_status_unpack" $ \ msg buf -> body $ do
  store (msg ~> satellites_visible) =<< call unpack buf 0
  arrayUnpack buf 1 (msg ~> satellite_prn)
  arrayUnpack buf 21 (msg ~> satellite_used)
  arrayUnpack buf 41 (msg ~> satellite_elevation)
  arrayUnpack buf 61 (msg ~> satellite_azimuth)
  arrayUnpack buf 81 (msg ~> satellite_snr)

