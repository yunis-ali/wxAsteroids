
  2009-03-07

  Asteroids.lhs 


> import Graphics.UI.WX
> import Graphics.UI.WXCore as WXCore
> import System.Directory   (setCurrentDirectory)
> import System.Random
> import Paths_wxAsteroids  (getDataDir)

The game consists of a spaceship that can move to the left and right 
using the arrow keys. There is an infinite supply of random rocks 
(asteroids) that move vertically downwards. Whenever the spaceship 
hits a rock, the rock becomes a flaming ball. In a more realistic 
version, this would destroy the ship, but we choose a more peaceful 
variant here. We start by defining some constants: 

> height   :: Int
> height   = 300 

> width    :: Int
> width    = 300 

> diameter :: Int
> diameter = 24 

> chance   :: Double 
> chance   = 0.1

One can access wxHaskell functionality, like the portable 
database binding, without using the GUI functionality. 

For simplicity, we use fixed dimensions for the game field, given 
by width and height. The diameter is the diameter of the rocks, and 
the chance is the chance that a new rock appears in a given time 
frame. The main function of our game is asteroids that creates the 
user interface: 

> asteroids :: IO () 
> asteroids = 
>   do
>     g      <- getStdGen 
>     vrocks <- varCreate $ randomRocks g
>     vship  <- varCreate $ div width 2
>     
>     f  <- frame   [ resizeable := False ]
      
      Status bar
      
>     status <- statusField [text := "Welcome to asteroids"] 
>     set f [statusBar := [status]] 
>     
>     t  <- timer f [ interval   := 50
>                   -- , on command := advance vrocks f
>                   , on command := advance status vrocks f
>                   ]
>     
>     game <- menuPane       [ text := "&Game" ] 
>     new  <- menuItem game  [ text := "&New\tCtrl+N" 
>                            , help := "New game"
>                            ] 
>     pause <- menuItem game [ text      := "&Pause\tCtrl+P" 
>                            , help      := "Pause game" 
>                            , checkable := True
>                            ] 
>     menuLine game 
>     quit <- menuQuit game [help := "Quit the game"] 
>	
>     set new   [on command := asteroids] 
>     set pause [on command := set t [enabled :~ not]] 
>     set quit  [on command := close f] 

The quit menu simply closes the frame. The pause menu toggles the 
enabled state of the timer by applying the not function. Turning off 
the timer effectively pauses the game. The new menu is interesting 
as it starts a completely new asteroids game in another frame. As we 
don�t use any global variables, the new game functions completely 
independent from any other asteroids game. Finally, we show the 
menu by specifying the menu bar of the frame: 

>     set f [menuBar := [game]] 
>     
>     set f [ text        := "Asteroids" 
>           , bgcolor     := white 
>           , layout      := space width height 
>           , on paint    := draw vrocks vship 
>           , on leftKey  := varUpdate vship (\x -> max 0     (x - 5)) >> return ()
>           , on rightKey := varUpdate vship (\x -> min width (x + 5)) >> return ()
>           , on (charKey '-') := set t [interval :~ \i -> i * 2] 
>           , on (charKey '+') := set t [interval :~ \i -> max 10 (div i 2)] 
>           ] 

The status is passed to the advance function, which updates the 
status field with the count of rocks that are currently visible: 

> advance :: (Textual w, Paint w1) => w -> Var [[a]] -> w1 -> IO ()
> advance status vrocks f = 
>   do 
>     (r : rs) <- varGet vrocks 
>     varSet vrocks rs
>     set status [text  := "rocks: " ++ show (length r)] 
>     repaint f 

The vrocks variable holds an infinite list of all future rock positions. 
This infinite list is generated by the randomRocks function 
that takes a random number generator g as its argument: 

> randomRocks :: RandomGen g => g -> [[Point]] 
> randomRocks g = flatten [] (map fresh (randoms g)) 


> flatten :: [[a]] -> [[[a]]] -> [[a]]
> flatten rocks (t : ts)= 
>   let now   = map head rocks 
>       later = filter (not . null) (map tail rocks) 
>   in now : flatten (t ++ later) ts 
> flatten _rocks [] = error "Empty rocks list not expected in function flatten"


> fresh :: Double -> [[Point2 Int]]
> fresh r 
>   | r > chance = [] 
>   | otherwise  = [track (floor (fromIntegral width * r / chance))] 


> track :: Int -> [Point2 Int]
> track x = [point x (y - diameter) | y <- [0, 6 .. height + 2 * diameter]] 


The standard randoms function generates an infinite list of random 
numbers in the range [0, 1). The fresh function compares each number 
agains the chance, and if a new rock should appear, it generates 
a finite list of positions that move the rock from the top to the bottom 
of the game field. The expression map fresh (randoms g) 
denotes an infinite list, where each element contains either an empty 
list, or a list of positions for a new rock. Finally, we flatten this list 
into a list of time frames, where each element contains the position 
of every rock in that particular time frame. 

> draw :: Var [[Point2 Int]] -> Var Int -> DC a -> b -> IO ()
> draw vrocks vship dc _view =
>   do
>     rocks <- varGet vrocks 
>     x     <- varGet vship 
>
>     let
>       shipLocation = point x (height - 2 * diameter)
>       positions    = head rocks
>       collisions   = map (collide shipLocation) positions
>       
>     drawShip dc shipLocation
>     mapM (drawRock dc) (zip positions collisions) 
>
>     when (or collisions)
>       (play explode) 

The draw function was partially parameterised with the vrocks and 
vship variables. The last two parameters are supplied by the paint 
event handler: the current device context (dc) and view area (view). 
The device context is in this case the window area on the screen, 
but it could also be a printer or bitmap for example. 

First, we retrieve the current rocks and x position of the spaceship. 
The position of the spaceship, ship, is at a fixed y-position. The 
current rock positions are simply the head of the rocks list. The 
collisions list tells for each rock position whether it collides with the 
ship. Finally, we draw the ship and all the rocks. As a final touch, 
we also play a sound fragment of an explosion when a collision 
has happened. The collide function just checks if two positions 
are too close for comfort using standard vector functions from the 
wxHaskell library: 


> collide :: Point2 Int -> Point2 Int -> Bool
> collide pos0 pos1 = 
>   let distance = vecLength (vecBetween pos0 pos1) 
>   in distance <= fromIntegral diameter 


> drawShip :: DC a -> Point -> IO ()
> drawShip dc pos = drawBitmap dc ship pos True [] 


> drawRock :: DC a -> (Point, Bool) -> IO ()
> drawRock dc (pos, collides)= 
>   let rockPicture = if collides then burning else rock
>   in drawBitmap dc rockPicture pos True []


The drawBitmap function takes a device context, a bitmap, a position, 
the transparency mode, and a list of properties as arguments. 
The bitmap for a rock is changed to a burning ball when it collides 
with the spaceship. To finish the program, we define the resources 
that we used: 

> rock    :: Bitmap ()
> rock    = bitmap "rock.ico"

> burning :: Bitmap ()
> burning = bitmap "burning.ico"

> ship    :: Bitmap ()
> ship    = bitmap "ship.ico"

> explode :: WXCore.Sound ()
> explode = sound  "explode.wav" 


> main :: IO ()
> main = 
>   do
>     dataDirectory <- getDataDir
>     setCurrentDirectory dataDirectory 
>     start asteroids

