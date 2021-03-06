module Test.Main where

import Prelude

import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, logShow, log)
import Control.Monad.Rec.Loops (whileM_)
import Data.Array as Array
import Data.Foldable (for_, oneOfMap)
import Run (EFF, FProxy, Run, SProxy(..), lift, liftEff, on, extract, runBaseEff, run, send)
import Run.Choose (CHOOSE, runChoose)
import Run.Except (EXCEPT, runExcept, throw, catch)
import Run.State (STATE, runState, get, gets, put, modify)
import Test.Examples as Examples

data Talk a
  = Speak String a
  | Listen (String → a)

derive instance functorTalk ∷ Functor Talk

type TALK = FProxy Talk

_talk ∷ SProxy "talk"
_talk = SProxy

speak ∷ ∀ r. String → Run (talk ∷ TALK | r) Unit
speak a = lift _talk $ Speak a unit

listen ∷ ∀ r. Run (talk ∷ TALK | r) String
listen = lift _talk $ Listen id

---

program ∷ ∀ r. String → Run (except ∷ EXCEPT String, state ∷ STATE String | r) Int
program a = do
  put "Hello"
  if a == "12"
    then put "World" $> 12
    else throw "Not 12"

program2 ∷ ∀ eff r. Run (state ∷ STATE Int, eff ∷ EFF (console ∷ CONSOLE | eff) | r) Int
program2 = do
  for_ (Array.range 1 100000) \n → do
    modify (_ + 1)
  liftEff $ log "Done"
  get

program3 ∷ ∀ r. Run (talk ∷ TALK | r) Unit
program3 = do
  speak "Hello, there."
  speak "What is your name?"
  name ← listen
  speak $ "Nice to meet you, " <> name <> "!"

type MyEffects eff =
  ( state ∷ STATE Int
  , except ∷ EXCEPT String
  , eff ∷ EFF (console ∷ CONSOLE | eff)
  )

yesProgram ∷ ∀ eff. Run (MyEffects eff) Unit
yesProgram = do
  whenM (gets (_ < 0)) do
    throw "Number is less than 0"
  whileM_ (gets (_ > 0)) do
    liftEff $ log "Yes"
    modify (_ - 1)

chooseProgram ∷ ∀ eff r. Run (choose ∷ CHOOSE, eff ∷ EFF (console ∷ CONSOLE | eff) | r) Int
chooseProgram = do
  n ← oneOfMap pure [1, 2, 3, 4, 5]
  liftEff $ log $ show n
  pure (n + 1)

main ∷ Eff (console ∷ CONSOLE, timer :: Examples.TIMER) Unit
main = do
  program "42" # runState "" # runExcept # extract # logShow
  program "42" # runExcept # runState "" # extract # logShow
  program "12" # runState "" # runExcept # extract # logShow

  res1 ← program2 # runState 0 # runBaseEff
  logShow res1

  let
    runSpeak = send # on _talk case _ of
      Speak str a  → liftEff (log str) $> a
      Listen reply → pure $ reply "Gerald"

  program3
    # run runSpeak
    # runBaseEff

  yesProgram
    # catch (liftEff <<< log)
    # runState 10
    # runBaseEff
    # void

  as ← chooseProgram
    # runChoose
    # runBaseEff
  logShow (as ∷ Array Int)

  Examples.main >>= logShow
  Examples.mainSleep
