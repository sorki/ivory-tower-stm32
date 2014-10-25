{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DataKinds #-}

module Ivory.Tower.Test where

import Ivory.Tower
import Ivory.Language
import Ivory.Tower.AST.Graph
import Text.Show.Pretty

import Ivory.Compile.C.CmdlineFrontend

data Test = Test String (Tower ())

test1 :: Test
test1 = Test "test1" $ do
  (c1in, c1out) <- channel
  per <- period (Microseconds 1000)
  monitor "m1" $ do
    (_s :: Ref Global (Stored IBool)) <- state "some_m1_state"
    handler per "tick" $ do
      e <- emitter c1in 1
      callback $ \m -> do
        comment "some_ivory_in_m1_tick"
        emit e m
  monitor "m2" $ do
    (_s :: Ref Global (Stored IBool))<- state "some_m2_state"
    handler c1out "chan1msg" $ do
      callback $ \_ -> comment "some_ivory_in_m2_onmsg"

test2 :: Test
test2 = Test "test2" $ do
  (c1in, c1out) <- channel
  per1 <- period (Microseconds 1000)
  per2 <- period (Microseconds 333)
  monitor "m1" $ do
    (_s :: Ref Global (Stored IBool)) <- state "some_m1_state"
    handler per1 "tick1" $ do
      e <- emitter c1in 1
      callback $ \m -> do
        comment "some_ivory_in_m1_tick2"
        emit e m
    handler per2 "tick2" $ do
      e <- emitter c1in 1
      callback $ \m -> do
        comment "some_ivory_in_m1_tick2"
        emit e m
  monitor "m2" $ do
    (_s :: Ref Global (Stored Uint32)) <- state "some_m2_state"
    handler c1out "chan1msg" $ do
      callback $ \_ -> comment "some_ivory_in_m2_onmsg"

test3 :: Test
test3 = Test "test3" $ do
  (c1in, c1out) <- channel
  (c2in, c2out) <- channel
  p1 <- period (Microseconds 1000)
  p2 <- period (Microseconds 666)
  monitor "m1" $ do
    (_s :: Ref Global (Stored Uint8)) <- state "some_m1_state"
    handler p1 "tick" $ do
      e <- emitter c1in 1
      callback $ \m -> do
        comment "some_ivory_in_m1_tick"
        emit e m
  monitor "m2" $ do
    (_s :: Ref Global (Stored Uint8)) <- state "some_m2_state"
    handler c1out "chan1msg" $ do
      e <- emitter c2in 1
      callback $ \m -> do
        comment "some_ivory_in_m2_onmsg"
        emit e m
  monitor "m3" $ do
    (_s :: Ref Global (Stored Uint8)) <- state "some_m3_state"
    handler c1out "chan1msg" $ do
      e <- emitter c2in 1
      callback $ \m -> do
        comment "some_ivory_in_m3_onchan1"
        emit e m
    handler c2out "chan2msg" $ do
      callback $ \_ -> comment "some_ivory_in_m3_onchan2"
    handler p2 "tick2" $ do
      e <- emitter c1in 3
      callback $ \m -> do
        comment "some ivory in m3 tick2"
        emit e m
  monitor "m4" $ do
    (_s :: Ref Global (Stored Uint8)) <- state "some_m4_state"
    handler c2out "chan2msg" $ do
      callback $ \_ -> comment "some_ivory_in_m4_onmsg"

run :: Test -> IO ()
run (Test dir t) = do
  putStrLn (ppShow ast)
  putStrLn "\n=======\n"
  let graph = messageGraph ast
      dot = graphviz graph
  putStrLn dot
  writeFile "out.dot" dot
  _ <- runCompiler code initialOpts { srcDir = dir, includeDir = dir }
  return ()
  where
  (ast, code) = tower t
