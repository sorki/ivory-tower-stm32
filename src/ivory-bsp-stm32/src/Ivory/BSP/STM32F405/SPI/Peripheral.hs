{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
--
-- Peripheral.hs --- SPI peripheral driver for the STM32F4.
--
-- Copyright (C) 2013, Galois, Inc.
-- All Rights Reserved.
--

module Ivory.BSP.STM32F405.SPI.Peripheral where

import Ivory.Language
import Ivory.BitData
import Ivory.HW
import Ivory.Stdlib

import Ivory.BSP.STM32.Signalable

import Ivory.BSP.STM32F405.SPI.RegTypes
import Ivory.BSP.STM32F405.SPI.Regs

import Ivory.BSP.STM32F405.RCC
import Ivory.BSP.STM32F405.GPIO
import Ivory.BSP.STM32F405.GPIO.AF
import Ivory.BSP.STM32F405.MemoryMap

import           Ivory.BSP.STM32F405.Interrupt (Interrupt())
import qualified Ivory.BSP.STM32F405.Interrupt as ISR

data SPIPeriph i = SPIPeriph
  { spiRegCR1      :: BitDataReg SPI_CR1
  , spiRegCR2      :: BitDataReg SPI_CR2
  , spiRegSR       :: BitDataReg SPI_SR
  , spiRegDR       :: BitDataReg SPI_DR
  , spiRCCEnable   :: forall eff . Ivory eff ()
  , spiRCCDisable  :: forall eff . Ivory eff ()
  , spiPinMiso     :: GPIOPin
  , spiPinMosi     :: GPIOPin
  , spiPinSck      :: GPIOPin
  , spiPinAF       :: GPIO_AF
  , spiInterrupt   :: i
  , spiPClk        :: PClk
  , spiName        :: String
  }

mkSPIPeriph :: (BitData a, IvoryIOReg (BitDataRep a))
            => Integer
            -> BitDataReg a
            -> BitDataField a Bit
            -> GPIOPin
            -> GPIOPin
            -> GPIOPin
            -> GPIO_AF
            -> Interrupt
            -> PClk
            -> String
            -> SPIPeriph Interrupt
mkSPIPeriph base rccreg rccfield miso mosi sck af inter pclk n =
  SPIPeriph
    { spiRegCR1      = reg 0x00 "cr1"
    , spiRegCR2      = reg 0x04 "cr2"
    , spiRegSR       = reg 0x08 "sr"
    , spiRegDR       = reg 0x0C "dr"
    , spiRCCEnable   = rccEnable  rccreg rccfield
    , spiRCCDisable  = rccDisable rccreg rccfield
    , spiPinMiso     = miso
    , spiPinMosi     = mosi
    , spiPinSck      = sck
    , spiPinAF       = af
    , spiInterrupt   = inter
    , spiPClk        = pclk
    , spiName        = n
    }
  where
  reg :: (IvoryIOReg (BitDataRep d)) => Integer -> String -> BitDataReg d
  reg offs name = mkBitDataRegNamed (base + offs) (n ++ "->" ++ name)

spi1, spi2, spi3 :: SPIPeriph Interrupt
spi1 = mkSPIPeriph spi1_periph_base regRCC_APB2ENR rcc_apb2en_spi1
          pinA7  pinA6  pinA5  gpio_af_spi1 ISR.SPI1 PClk2 "spi1"
spi2 = mkSPIPeriph spi2_periph_base regRCC_APB1ENR rcc_apb1en_spi2
          pinC3  pinC2  pinB10 gpio_af_spi2 ISR.SPI2 PClk1 "spi2"
spi3 = mkSPIPeriph spi3_periph_base regRCC_APB1ENR rcc_apb1en_spi3
          pinC12 pinC11 pinC10 gpio_af_spi3 ISR.SPI3 PClk1 "spi3"

initInPin :: GPIOPin -> GPIO_AF -> Ivory eff ()
initInPin pin af = do
  pinEnable  pin
  pinSetAF   pin af
  pinSetMode pin gpio_mode_af
  pinSetPUPD pin gpio_pupd_none

initOutPin :: GPIOPin -> GPIO_AF -> Ivory eff ()
initOutPin pin af = do
  pinEnable        pin
  pinSetAF         pin af
  pinSetMode       pin gpio_mode_af
  pinSetOutputType pin gpio_outputtype_pushpull

-- | Enable peripheral and setup GPIOs. Must be performed
--   before any other SPI peripheral actions.
spiInit :: (GetAlloc eff ~ Scope s) => SPIPeriph i -> Ivory eff ()
spiInit spi = do
  spiRCCEnable spi
  initInPin  (spiPinMiso spi) (spiPinAF spi)
  initOutPin (spiPinMosi spi) (spiPinAF spi)
  initOutPin (spiPinSck  spi) (spiPinAF spi)

spiInitISR :: (STM32Signal p, GetAlloc eff ~ Scope s)
           => SPIPeriph (STM32Interrupt p) -> Ivory eff ()
spiInitISR spi = do
  interrupt_set_to_syscall_priority inter
  interrupt_enable                  inter
  where
  inter = spiInterrupt spi

spiISRHandlerName :: (STM32Signal p) => SPIPeriph (STM32Interrupt p) -> String
spiISRHandlerName spi = interruptHandlerName (spiInterrupt spi)

-- Clock Polarity and Phase: see description
-- of CPOL and CPHA in ST reference manual RM0090
data SPICSActive      = ActiveHigh | ActiveLow
data SPIClockPolarity = ClockPolarityLow | ClockPolarityHigh
data SPIClockPhase    = ClockPhase1 | ClockPhase2
data SPIBitOrder      = LSBFirst | MSBFirst

data SPIDevice i = SPIDevice
  { spiDevPeripheral    :: SPIPeriph i
  , spiDevCSPin         :: GPIOPin
  , spiDevClockHz       :: Integer
  , spiDevCSActive      :: SPICSActive
  , spiDevClockPolarity :: SPIClockPolarity
  , spiDevClockPhase    :: SPIClockPhase
  , spiDevBitOrder      :: SPIBitOrder
  , spiDevName          :: String
  }

spiDeviceInit :: (GetAlloc eff ~ Scope s) => SPIDevice i -> Ivory eff ()
spiDeviceInit dev = do
  let pin = spiDevCSPin dev
  pinEnable         pin
  spiDeviceDeselect dev
  pinSetMode        pin gpio_mode_output
  pinSetOutputType  pin gpio_outputtype_pushpull
  pinSetSpeed       pin gpio_speed_2mhz

spiBusBegin :: (GetAlloc eff ~ Scope cs, BoardHSE p)
            => Proxy p -> SPIDevice i -> Ivory eff ()
spiBusBegin platform dev = do
  -- XXX can i eliminate this on/off cycle?
  spiModifyCr1        periph [ spi_cr1_spe ] true
  spiClearCr1         periph
  spiClearCr2         periph
  -- XXX Can we change the platform code to just calculate this
  -- statically? Shouldn't need runtime config, since that should
  -- always be the same
  baud <- spiDevBaud  platform periph (spiDevClockHz dev)
  modifyReg (spiRegCR1 periph) $ do
    setBit   spi_cr1_mstr
    setBit   spi_cr1_ssm
    setBit   spi_cr1_ssi
    setField spi_cr1_br baud
    setBit   spi_cr1_spe
    case spiDevClockPolarity dev of
      ClockPolarityLow  -> clearBit spi_cr1_cpol
      ClockPolarityHigh -> setBit  spi_cr1_cpol
    case spiDevClockPhase dev of
      ClockPhase1 -> clearBit spi_cr1_cpha
      ClockPhase2 -> setBit   spi_cr1_cpha
    case spiDevBitOrder dev of
      LSBFirst -> setBit   spi_cr1_lsbfirst
      MSBFirst -> clearBit spi_cr1_lsbfirst
  where
  periph = spiDevPeripheral dev


spiBusEnd :: SPIPeriph i -> Ivory eff ()
spiBusEnd  periph =
  spiModifyCr1 periph [ spi_cr1_spe ] false

spiDeviceEnd :: SPIDevice i -> Ivory eff ()
spiDeviceEnd dev = do
  spiDeviceDeselect dev
  spiBusEnd         periph
  where periph = spiDevPeripheral dev


spiSetTXEIE :: SPIPeriph i -> Ivory eff ()
spiSetTXEIE spi = modifyReg (spiRegCR2 spi) $ setBit spi_cr2_txeie

spiClearTXEIE :: SPIPeriph i -> Ivory eff ()
spiClearTXEIE spi = modifyReg (spiRegCR2 spi) $ clearBit spi_cr2_txeie

spiSetRXNEIE :: SPIPeriph i -> Ivory eff ()
spiSetRXNEIE spi = modifyReg (spiRegCR2 spi) $ setBit spi_cr2_rxneie

spiClearRXNEIE :: SPIPeriph i -> Ivory eff ()
spiClearRXNEIE spi = modifyReg (spiRegCR2 spi) $ clearBit spi_cr2_rxneie

spiGetDR :: SPIPeriph i -> Ivory eff Uint8
spiGetDR spi = do
  r <- getReg (spiRegDR spi)
  return (toRep (r #. spi_dr_data))

spiSetDR :: SPIPeriph i -> Uint8 -> Ivory eff ()
spiSetDR spi b =
  setReg (spiRegDR spi) $
    setField spi_dr_data (fromRep b)

-- Internal Helper Functions ---------------------------------------------------

spiDevBaud :: (GetAlloc eff ~ Scope s, BoardHSE p)
           => Proxy p -> SPIPeriph i -> Integer -> Ivory eff SPIBaud
spiDevBaud platform periph hz = do
  fplk <- getFreqPClk platform (spiPClk periph)
  comment ("got fplk, target is " ++ show hz)
  let bestWithoutGoingOver = map aux tbl
      target = fromIntegral hz
      aux (br, brdiv) =
        ((fplk `iDiv` brdiv) <? target) ==> return br
  cond (bestWithoutGoingOver ++ [ true ==> return spi_baud_div_256 ])
  where
  tbl = [( spi_baud_div_2,   2)
        ,( spi_baud_div_4,   4)
        ,( spi_baud_div_8,   8)
        ,( spi_baud_div_16,  16)
        ,( spi_baud_div_32,  32)
        ,( spi_baud_div_64,  64)
        ,( spi_baud_div_128, 128)
        ,( spi_baud_div_256, 256)]

spiDeviceSelect   :: SPIDevice i -> Ivory eff ()
spiDeviceSelect dev = case spiDevCSActive dev of
  ActiveHigh -> pinSet   (spiDevCSPin dev)
  ActiveLow  -> pinClear (spiDevCSPin dev)

spiDeviceDeselect :: SPIDevice i -> Ivory eff ()
spiDeviceDeselect dev = case spiDevCSActive dev of
  ActiveHigh -> pinClear (spiDevCSPin dev)
  ActiveLow  -> pinSet   (spiDevCSPin dev)

spiSetBaud :: SPIPeriph i -> SPIBaud -> Ivory eff ()
spiSetBaud periph baud = modifyReg (spiRegCR1 periph) $ setField spi_cr1_br baud

spiModifyCr1 :: SPIPeriph i -> [BitDataField SPI_CR1 Bit] -> IBool -> Ivory eff ()
spiModifyCr1 periph fields b =
  modifyReg (spiRegCR1 periph) $ mapM_ (\f -> setField f (boolToBit b)) fields

spiClearCr1 :: SPIPeriph i -> Ivory eff ()
spiClearCr1 periph = modifyReg (spiRegCR1 periph) $ do
  -- It may not be strictly necessary to clear all of these fields.
  -- I'm copying the implementation of the HWF4 lib, where REG->CR1 is set to 0
  clearBit spi_cr1_bidimode
  clearBit spi_cr1_bidioe
  clearBit spi_cr1_crcen
  clearBit spi_cr1_crcnext
  clearBit spi_cr1_dff
  clearBit spi_cr1_rxonly
  clearBit spi_cr1_ssm
  clearBit spi_cr1_ssi
  clearBit spi_cr1_lsbfirst
  clearBit spi_cr1_spe
  setField spi_cr1_br spi_baud_div_2
  clearBit spi_cr1_mstr
  clearBit spi_cr1_cpol
  clearBit spi_cr1_cpha

spiClearCr2 :: SPIPeriph i -> Ivory eff ()
spiClearCr2 periph = modifyReg (spiRegCR2 periph) $ do
  -- May not be strictly necessary to set all these fields, see comment
  -- for spiClearCr1
  clearBit spi_cr2_txeie
  clearBit spi_cr2_rxneie
  clearBit spi_cr2_errie
  clearBit spi_cr2_ssoe
  clearBit spi_cr2_txdmaen
  clearBit spi_cr2_rxdmaen

spiSetClockPolarity :: SPIPeriph i -> SPIClockPolarity -> Ivory eff ()
spiSetClockPolarity periph polarity =
  modifyReg (spiRegCR1 periph) $ case polarity of
    ClockPolarityLow  -> clearBit spi_cr1_cpol
    ClockPolarityHigh -> setBit  spi_cr1_cpol

spiSetClockPhase :: SPIPeriph i -> SPIClockPhase -> Ivory eff ()
spiSetClockPhase periph phase =
  modifyReg (spiRegCR1 periph) $ case phase of
    ClockPhase1 -> clearBit spi_cr1_cpha
    ClockPhase2 -> setBit   spi_cr1_cpha

spiSetBitOrder :: SPIPeriph i-> SPIBitOrder -> Ivory eff ()
spiSetBitOrder periph bitorder =
  modifyReg (spiRegCR1 periph) $ case bitorder of
    LSBFirst -> setBit   spi_cr1_lsbfirst
    MSBFirst -> clearBit spi_cr1_lsbfirst

