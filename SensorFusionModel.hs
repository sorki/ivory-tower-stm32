{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module SensorFusionModel where

import ExtendedKalmanFilter
import Matrix
import Quat
import Vec3

import Control.Applicative
import Data.Distributive
import Data.Foldable (Foldable(..), toList)
import Data.Traversable

-- For measurements/states in navigation frame
newtype NED a = NED { nedToVec3 :: Vec3 a }
    deriving (Show, Applicative, Pointwise, Foldable, Functor, Traversable, Distributive, Num)

ned :: a -> a -> a -> NED a
ned n e d = NED $ Vec3 n e d

-- For measurements/states in body frame
newtype XYZ a = XYZ { xyzToVec3 :: Vec3 a }
    deriving (Show, Applicative, Pointwise, Foldable, Functor, Traversable, Distributive, Num)

xyz :: a -> a -> a -> XYZ a
xyz a b c = XYZ $ Vec3 a b c

-- Rotate between coordinate frames through a given quaternion
convertFrames :: Num a => Quat a -> (XYZ a -> NED a, NED a -> XYZ a)
convertFrames q = (toNav, toBody)
    where
    rotate2nav = NED $ fmap XYZ $ quatRotation q
    toNav = matVecMult rotate2nav
    toBody = matVecMult (matTranspose rotate2nav)

data StateVector a = StateVector
    { stateOrient :: !(Quat a) -- quaternions defining attitude of body axes relative to local NED
    , stateVel :: !(NED a) -- NED velocity - m/sec
    , statePos :: !(NED a) -- NED position - m
    , stateGyroBias :: !(XYZ a) -- delta angle bias - rad
    , stateWind :: !(NED a) -- NED wind velocity - m/sec
    , stateMagNED :: !(NED a) -- NED earth fixed magnetic field components - milligauss
    , stateMagXYZ :: !(XYZ a) -- XYZ body fixed magnetic field measurements - milligauss
    }
    deriving Show

instance Applicative StateVector where
    pure v = StateVector
        { stateOrient = pure v
        , stateVel = pure v
        , statePos = pure v
        , stateGyroBias = pure v
        , stateWind = pure v
        , stateMagNED = pure v
        , stateMagXYZ = pure v
        }
    v1 <*> v2 = StateVector
        { stateOrient = stateOrient v1 <*> stateOrient v2
        , stateVel = stateVel v1 <*> stateVel v2
        , statePos = statePos v1 <*> statePos v2
        , stateGyroBias = stateGyroBias v1 <*> stateGyroBias v2
        , stateWind = stateWind v1 <*> stateWind v2
        , stateMagNED = stateMagNED v1 <*> stateMagNED v2
        , stateMagXYZ = stateMagXYZ v1 <*> stateMagXYZ v2
        }
instance Pointwise StateVector where

instance Functor StateVector where
    fmap = liftA

instance Foldable StateVector where
    foldMap = foldMapDefault

instance Traversable StateVector where
    sequenceA v = StateVector
        <$> sequenceA (stateOrient v)
        <*> sequenceA (stateVel v)
        <*> sequenceA (statePos v)
        <*> sequenceA (stateGyroBias v)
        <*> sequenceA (stateWind v)
        <*> sequenceA (stateMagNED v)
        <*> sequenceA (stateMagXYZ v)

instance Distributive StateVector where
    distribute f = StateVector
        { stateOrient = distribute $ fmap stateOrient f
        , stateVel = distribute $ fmap stateVel f
        , statePos = distribute $ fmap statePos f
        , stateGyroBias = distribute $ fmap stateGyroBias f
        , stateWind = distribute $ fmap stateWind f
        , stateMagNED = distribute $ fmap stateMagNED f
        , stateMagXYZ = distribute $ fmap stateMagXYZ f
        }

-- Define the control (disturbance) vector. Error growth in the inertial
-- solution is assumed to be driven by 'noise' in the delta angles and
-- velocities, after bias effects have been removed. This is OK becasue we
-- have sensor bias accounted for in the state equations.
data DisturbanceVector a = DisturbanceVector
    { disturbanceGyro :: !(XYZ a) -- XYZ body rotation rate in rad/second
    , disturbanceAccel :: !(XYZ a) -- XYZ body acceleration in meters/second/second
    }
    deriving Show

instance Applicative DisturbanceVector where
    pure v = DisturbanceVector
        { disturbanceGyro = pure v
        , disturbanceAccel = pure v
        }
    v1 <*> v2 = DisturbanceVector
        { disturbanceGyro = disturbanceGyro v1 <*> disturbanceGyro v2
        , disturbanceAccel = disturbanceAccel v1 <*> disturbanceAccel v2
        }
instance Pointwise DisturbanceVector where

instance Functor DisturbanceVector where
    fmap = liftA

instance Foldable DisturbanceVector where
    foldMap = foldMapDefault

instance Traversable DisturbanceVector where
    sequenceA v = DisturbanceVector
        <$> sequenceA (disturbanceGyro v)
        <*> sequenceA (disturbanceAccel v)

instance Distributive DisturbanceVector where
    distribute f = DisturbanceVector
        { disturbanceGyro = distribute $ fmap disturbanceGyro f
        , disturbanceAccel = distribute $ fmap disturbanceAccel f
        }

nStates :: Int
nStates = length $ toList (pure () :: StateVector ())

-- Model initialization

kalmanP :: Fractional a => StateVector (StateVector a)
kalmanP = diagMat $ fmap (^ (2 :: Int)) $ StateVector
    { stateOrient = Quat 0.5 (Vec3 0.5 0.5 5)
    , stateVel = pure 0.7
    , statePos = ned 15 15 5
    , stateGyroBias = pure $ 0.1 * deg2rad * dtIMU
    , stateWind = pure 8
    , stateMagNED = pure 0.02
    , stateMagXYZ = pure 0.02
    }
    where
    deg2rad = realToFrac (pi :: Double) / 180
    dtIMU = 0.1 -- FIXME: get dt from caller

initAttitude :: RealFloat a => XYZ a -> XYZ a -> a -> Quat a
initAttitude (XYZ accel) (XYZ mag) declination = heading * pitch * roll
    where
    initialRoll = atan2 (negate (vecY accel)) (negate (vecZ accel))
    initialPitch = atan2 (vecX accel) (negate (vecZ accel))
    magX = (vecX mag) * cos initialPitch + (vecY mag) * sin initialRoll * sin initialPitch + (vecZ mag) * cos initialRoll * sin initialPitch
    magY = (vecY mag) * cos initialRoll - (vecZ mag) * sin initialRoll
    initialHdg = atan2 (negate magY) magX + declination
    roll = fromAxisAngle (Vec3 1 0 0) initialRoll
    pitch = fromAxisAngle (Vec3 0 1 0) initialPitch
    heading = fromAxisAngle (Vec3 0 0 1) initialHdg

initDynamic :: RealFloat a => XYZ a -> XYZ a -> XYZ a -> a -> NED a -> NED a -> StateVector a
initDynamic accel mag magBias declination vel pos = (pure 0)
    { stateOrient = initQuat
    , stateVel = vel
    , statePos = pos
    , stateMagNED = initMagNED
    , stateMagXYZ = magBias
    }
    where
    initMagXYZ = mag - magBias
    initQuat = initAttitude accel initMagXYZ declination
    initMagNED = fst (convertFrames initQuat) initMagXYZ
    -- TODO: re-implement InertialNav's calcEarthRateNED

-- Model noise parameters

gyroProcessNoise, accelProcessNoise :: Fractional a => a
gyroProcessNoise = 1.4544411e-2
accelProcessNoise = 0.5

distCovariance :: Fractional a => a -> DisturbanceVector a
distCovariance dt = fmap (^ (2 :: Int)) $ DisturbanceVector
    { disturbanceGyro = pure (dt * gyroProcessNoise)
    , disturbanceAccel = pure (dt * accelProcessNoise)
    }

velNoise :: Fractional a => NED a
velNoise = ned 0.04 0.04 0.08

posNoise :: Fractional a => NED a
posNoise = pure 4

tasNoise :: Fractional a => a
tasNoise = 2

magNoise :: Fractional a => XYZ a
magNoise = pure 0.0025

-- Kalman equations

body2nav :: Num a => StateVector a -> XYZ a -> NED a
body2nav = fst . convertFrames . stateOrient
nav2body :: Num a => StateVector a -> NED a -> XYZ a
nav2body = snd . convertFrames . stateOrient

processModel :: (Num a, Fractional a) => a -> StateVector a -> DisturbanceVector a -> StateVector a
processModel dt state dist = state
    -- This approximates the discretization of `qdot = 0.5 * <0, deltaAngle> * q`.
    -- It assumes that dt is sufficiently small. The closed-form analytic
    -- discretization requires dividing by |deltaAngle|, which may be 0.
    -- * _Strapdown Inertial Navigation Technology, 2nd Ed_, section 11.2.5 (on
    --   pages 319-320) gives qdot and its analytic discretization, without proof.
    -- * http://en.wikipedia.org/wiki/Discretization derives the general form of
    --   discretization, and mentions this approximation.
    -- * http://www.euclideanspace.com/physics/kinematics/angularvelocity/QuaternionDifferentiation2.pdf
    --   derives qdot from angular momentum.
    { stateOrient = (1 + fmap (* (dt / 2)) deltaQuat) * stateOrient state
    , stateVel = stateVel state + deltaVel
    , statePos = statePos state + fmap (* dt) (stateVel state + fmap (/ 2) deltaVel)
    -- remaining state vector elements are unchanged by the process model
    }
    where
    deltaQuat = Quat 0 $ xyzToVec3 $ disturbanceGyro dist - stateGyroBias state
    deltaVel = fmap (* dt) $ body2nav state (disturbanceAccel dist) + g
    g = ned 0 0 9.80665 -- NED gravity vector - m/sec^2

newtype Singleton a = Singleton a

instance Applicative Singleton where
    pure = Singleton
    Singleton a <*> Singleton b = Singleton (a b)
instance Pointwise Singleton where

instance Functor Singleton where
    fmap = liftA

instance Traversable Singleton where
    sequenceA (Singleton v) = fmap Singleton v

instance Foldable Singleton where
    foldMap = foldMapDefault

-- A Fusion is a function from measurement covariance and measurement to
-- innovation, innovation covariance, new state, and new estimated state
-- covariance.
--
-- This version only supports scalar measurements. It's useful for sequential
-- fusion. It's also useful for partial measurements, such as measuring only
-- altitude when you've modeled 3D position.
type Fusion var = var -> var -> StateVector var -> StateVector (StateVector var) -> (var, var, StateVector var, StateVector (StateVector var))
fusion :: Fractional var => Measurement StateVector var -> Fusion var
fusion v cov m state p = let (Singleton innov, Singleton (Singleton innovCov), state', p') = measurementUpdate state (Singleton (m, v)) (Singleton (Singleton cov)) p in (innov, innovCov, state', p')

fuseVel :: Fractional var => NED (Fusion var)
fuseVel = fusion <$> ned (Measurement $ vecX . getVel) (Measurement $ vecY . getVel) (Measurement $ vecZ . getVel)
    where
    getVel = nedToVec3 . stateVel

fusePos :: Fractional var => NED (Fusion var)
fusePos = fusion <$> ned (Measurement $ vecX . getPos) (Measurement $ vecY . getPos) (Measurement $ vecZ . getPos)
    where
    getPos = nedToVec3 . statePos

fuseTAS :: Floating var => Fusion var
fuseTAS = fusion $ Measurement $ \ state -> sqrt $ sum $ map (** 2) $ toList $ stateVel state - stateWind state

fuseMag :: Fractional var => XYZ (Fusion var)
fuseMag = fusion <$> xyz (Measurement $ vecX . getMag) (Measurement $ vecY . getMag) (Measurement $ vecZ . getMag)
    where
    getMag state = xyzToVec3 $ stateMagXYZ state + nav2body state (stateMagNED state)
