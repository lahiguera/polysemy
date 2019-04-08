{-# LANGUAGE AllowAmbiguousTypes #-}

module Polysemy.Internal.Tactics
  ( Tactics (..)
  , runT
  , bindT
  , pureT
  , liftT
  , runTactics
  , Tactical
  , WithTactics
  ) where

import Polysemy.Internal
import Polysemy.Internal.Union
import Polysemy.Internal.Effect

type Tactical e m r x = ∀ f. Functor f => Semantic (WithTactics e f m r) (f x)
type WithTactics e f m r = Tactics f m (e ': r) ': r

data Tactics f n r m a where
  GetInitialState     :: Tactics f n r m (f ())
  HoistInterpretation :: (a -> n b) -> Tactics f n r m (f a -> Semantic r (f b))


getInitialState :: forall f m r e. Semantic (WithTactics e f m r) (f ())
getInitialState = send @(Tactics _ m (e ': r)) GetInitialState


pureT :: a -> Tactical e m r a
pureT a = do
  istate <- getInitialState
  pure $ a <$ istate


runT
    :: m a
    -> Semantic (WithTactics e f m r)
                (Semantic (e ': r) (f a))
runT na = do
  istate <- getInitialState
  na'    <- bindT (const na)
  pure $ na' istate
{-# INLINE runT #-}


bindT
    :: (a -> m b)
    -> Semantic (WithTactics e f m r)
                (f a -> Semantic (e ': r) (f b))
bindT f = send $ HoistInterpretation f
{-# INLINE bindT #-}


liftT
    :: forall m f r e a
     . Functor f
    => Semantic r a
    -> Semantic (WithTactics e f m r) (f a)
liftT m = do
  a <- raise m
  pureT a
{-# INLINE liftT #-}


runTactics
   :: Functor f
   => f ()
   -> (∀ x. f (m x) -> Semantic r2 (f x))
   -> Semantic (Tactics f m r2 ': r) a
   -> Semantic r a
runTactics s d (Semantic m) = m $ \u ->
  case decomp u of
    Left x -> liftSemantic $ hoist (runTactics_b s d) x
    Right (Yo GetInitialState s' _ y) ->
      pure $ y $ s <$ s'
    Right (Yo (HoistInterpretation na) s' _ y) -> do
      pure $ y $ (d . fmap na) <$ s'
{-# INLINE runTactics #-}


runTactics_b
   :: Functor f
   => f ()
   -> (∀ x. f (m x) -> Semantic r2 (f x))
   -> Semantic (Tactics f m r2 ': r) a
   -> Semantic r a
runTactics_b = runTactics
{-# NOINLINE runTactics_b #-}
