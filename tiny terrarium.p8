pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
-- tiny terrarium
-- by helado de brownie

-- this source code is best
-- read in the pico-8 code
-- editor. try the education
-- edition if you don't have
-- access to it otherwise:
-- https://www.pico-8-edu.com/

-- because of the limited
-- visible line length, lines
-- are broken after 31
-- characters. function
-- declarations are written
-- with the function keyword on
-- its own line to make more
-- room for the name and
-- parameter list.
-->8
-- glossary
-- this is a comment-only tab
-- explaining the terminology
-- used throughout the code.

-- atom:
-- an individual particle that
-- is independently simulated.
-- every atom is represented by
-- a pico-8 color, or,
-- equivalently, an integer
-- from 0 to 15 inclusive. the
-- game state is completely
-- determined by what colors
-- are in what places.
-- atoms come in multiple types
-- that have their own special
-- interactions with other
-- atoms. these are described
-- by the comments in the
-- _update function.

-- board:
-- the place where the
-- simulation happens. it takes
-- up the entire screen and is
-- a rectangular grid of tiles,
-- each of which contains
-- exactly one atom, no more or
-- less.

-- move:
-- to move an atom from one
-- tile to an adjacent tile
-- means to swap it with air if
-- the latter tile has air in
-- it, or else to attempt a
-- special reaction. these
-- reactions are determined by
-- the move function.

-- tile:
-- a place on the board. it is
-- identified by a pair of
-- coordinates, integers that
-- are at least zero and at
-- most one less than the
-- respective dimension of the
-- board. a tile always has
-- exactly one atom in it.

-- turn:
-- one logical frame, which
-- happens about thirty times
-- per second. the board state
-- advances once per turn. this
-- is when all the rules and
-- relations between atoms are
-- checked.
-->8
-- optimization
-- this is a comment-only tab
-- explaining the optimization
-- principles used throughout
-- the code.

-- because most computations in
-- this code happen potentially
-- hundreds of times per frame,
-- it's very important to do
-- things as cheap as possible.
-- the primary way that pico-8
-- makes it easy to follow
-- performance properties is
-- using its built-in cpu meter
-- that can be toggled by
-- pressing ctrl+p while a cart
-- is running. the middle and
-- right numbers should read as
-- less than 1.00 as much of
-- the time as possible.
-- some optimization principles
-- are used throughout the
-- source code, which are
-- explained here.

-- use local variables for
-- repeated lookups.
-- looking up global variables
-- is significantly slower than
-- looking up locals, even when
-- no other computations are
-- involved. a function can be
-- sped up without changing the
-- rest of its code just by
-- inserting a local definition
-- at the beginning that has
-- the same name as a global
-- that is referred to more
-- than once, and is set to the
-- value of that global. e.g.,
--  local air=air

-- compute everything once.
-- nontrivial computations such
-- as performing arithmetic or
-- comparisons on values tend
-- to be slower than reading
-- local variables or
-- parameters. functions should
-- be designed so that they can
-- accept information that is
-- already known or otherwise
-- use preconditions, i.e.,
-- assume the inputs are valid
-- instead of checking them
-- when it is known ahead of
-- time that the function will
-- only be called on valid
-- inputs.

-- inline.
-- writing separate functions
-- is useful for the sake of
-- code reuse, but calling them
-- has a cost that is not
-- always worth the tradeoff.
-- avoid calling functions when
-- it would noticeably slow
-- down the code, and instead
-- write the logic at the site
-- it's used.
-- this principle in particular
-- should only be applied when
-- it leads to *observable*
-- performance increase, in
-- order to offset its tendency
-- to make logic harder to
-- follow or make code harder
-- to maintain.
-->8
-- constants

-- board sizes larger than
-- 64x64 cause glitches because
-- they overlap the section of
-- the sprite sheet that the
-- move function uses for
-- metadata.
board_width,board_height=32,32

water= 1 -- dark blue
clay = 4 -- brown
block= 5 -- dark gray
egg  = 6 -- light gray
bug  = 8 -- red
plant=11 -- light green
air  =12 -- light blue
oil  =13 -- lavender
sand =15 -- tan
-->8
-- state

-- the board state is the
-- section of the sprite sheet
-- starting at (0,0) and sized
-- based on the board_width and
-- board_height constants.

-- the move state is the same
-- size as the board state but
-- begins at (64,0).

-- the cursor location is where
-- the player affects the board
-- when placing or erasing
-- atoms. it starts in the
-- center of the board.
cursor_x,cursor_y=
 board_width\2,board_height\2

-- the following variables are
-- set based on options that
-- the player can configure.
-- this happens when the game
-- loads and when the options
-- screen is closed.

-- the atom that will be placed
-- when the player presses 🅾️.
-- valid values are any defined
-- atoms.
drawn_atom=nil

-- the size of the area that
-- the player draws each frame.
-- valid values are sequences
-- of 2 elements, each a
-- positive integer.
brush=nil

-- if true, all atoms except
-- bugs will be overwritten;
-- otherwise, only air will be.
-- valid values: true, false
overdraw=nil

-- if true, erasing only works
-- on the currently selected
-- atom type (drawn_atom).
-- valid values: true, false
erase_type=nil

-- the function used to check
-- whether the cursor should
-- move.
-- example values: btn, btnp
cursor_check=nil

-- how fast the simulation
-- proceeds. larger is slower.
-- nil means time is stopped.
-- valid values are positive
-- integers and nil.
time_speed=nil

-- the atom that fills the out
-- of bounds area. these atoms
-- aren't affected by time and
-- can't individually change,
-- but in bounds atoms can
-- interact with them. see the
-- move function.
-- valid values are any defined
-- atoms.
out_of_bounds=nil
-->8
-- setup

function
_init()
 update_options()
 set_screen(simulation_screen)
end

-- change what "screen" the
-- game is on by swapping out
-- the _update and _draw
-- functions.
-- the given table should have
-- fields 'update' and 'draw'.
function
set_screen(screen)
 _update=screen.update
 _draw=screen.draw
end
-->8
-- simulation

simulation_screen={}
tick=-1

function
simulation_screen.update()
 -- the pause button opens the
 -- options screen.
 if btnp(6) then
  poke(0x5f30,1)
  set_screen(options_screen)
  return
 end

 local bw,bh=
  board_width,board_height
 local water=water
 local clay=clay
 local egg=egg
 local bug=bug
 local plant=plant
 local oil=oil
 local sand=sand

 local time_speed=time_speed
 local t=tick
 if(time_speed==nil)goto after
 t=(t+1)%time_speed
 tick=t
 if(t~=0)goto after

 -- simulate each atom.
 for y=0,bh-1 do
  for x=0,bw-1 do
   local atom=sget(x,y)
   -- water and oil fall
   -- straight down if able, or
   -- else move left or right
   -- or stay still at random.
   if
    atom==water or
    atom==oil
   then
    if not move(x,y,x,y+1) then
     local side=flr(rnd(3))-1
     move(x,y,x+side,y)
    end
   -- egg falls straight down,
   -- left, or right at random,
   -- or may hatch.
   elseif atom==egg then
    local side=flr(rnd(3))-1
    local moved=
     move(x,y,x+side,y+1)
    if
     not moved and
     flr(rnd(3600))==0
    then
     sset(x,y,bug)
     sset(x+64,y,1)
    end
   -- bug falls straight down,
   -- or may move in a random
   -- direction. it may lay an
   -- egg if there's room.
   elseif atom==bug then
    if
     not move(x,y,x,y+1) and
     flr(rnd(15))==0
    then
     local sidex=flr(rnd(3))-1
     local sidey=flr(rnd(3))-1
     move(
      x,y,
      x+sidex,y+sidey,
      true
     )
    end
   -- plant may grow in a
   -- random direction if there
   -- is water there.
   elseif atom==plant then
    local sidex=flr(rnd(3))-1
    local sidey=flr(rnd(3))-1
    move(
     x,y,
     x+sidex,y+sidey
    )
   -- clay falls straight down.
   elseif atom==clay then
    move(x,y,x,y+1)
   -- sand falls straight down,
   -- left, or right at random.
   elseif atom==sand then
    local side=flr(rnd(3))-1
    move(x,y,x+side,y+1)
   end
  end
 end

 -- we're done moving things;
 -- forget this turn's moves.
 poke(0x5f55,0x00)
 rectfill(64,0,128,64,0)
 poke(0x5f55,0x60)

 ::after::

 -- respond to player input.

 -- ⬅️➡️⬆️⬇️ move the cursor.
 local btn=cursor_check
 local cx,cy=cursor_x,cursor_y
 local brw,brh=
  brush[1],brush[2]
 if(btn(⬅️))cx-=1
 if(btn(➡️))cx+=1
 if(btn(⬆️))cy-=1
 if(btn(⬇️))cy+=1
 cx,cy=
  mid(0,cx,bw-brw),
  mid(0,cy,bh-brh)
 cursor_x,cursor_y=cx,cy

 -- 🅾️ replaces the atom under
 -- the cursor with the
 -- selected atom if:
 -- - overdraw is enabled; or
 -- - the atom under the cursor
 --   is air.
 -- ❎ replaces the atom under
 -- the cursor with air if:
 -- - erase_type is enabled and
 --   the atom is the same as
 --   the selected atom; or
 -- - erase_type is disabled.
 local atom
 if(btn(🅾️))atom=drawn_atom
 if(btn(❎))atom=air
 if atom~=nil then
  for x=cx,cx+brw-1 do
   for y=cy,cy+brh-1 do
    local atom_here=sget(x,y)
    if(atom_here==bug)goto next
    if atom==air then
     if
      erase_type and
      atom_here~=drawn_atom
     then
      goto next
     end
    else
     if
      atom_here~=air and
      not overdraw
     then
      goto next
     end
    end
    sset(x,y,atom)
    ::next::
   end
  end
 end
end

function
simulation_screen.draw()
 local bw,bh=
  board_width,board_height

 -- fill the screen with the
 -- board. because normally
 -- nothing will show through,
 -- we don't need to clear the
 -- screen explicitly.
 sspr(
  -- sprite sheet position
  0,0,
  -- sprite size
  bw,bh,
  -- screen position
  0,0,
  -- screen size
  128,128
 )

 -- draw the cursor.
 local brw,brh=
  brush[1],brush[2]
 -- compute width and height
 -- based on screen and board
 -- sizes.
 local cw,ch=
  128/bw,128/bh
 -- compute screen position
 -- based on logical position
 -- and cursor size.
 local csx,csy=
  cursor_x*cw,cursor_y*ch
 -- draw it as a black outline.
 rect(
  csx-1,csy-1,
  csx+cw*brw,csy+ch*brh,
  0
 )
end

-- move the atom at (x1,y1) to
-- (x2,y2). the result of this
-- depends on the interactions
-- specified by the logic for
-- each element, but broadly
-- speaking either ends up
-- changing the two atoms or
-- doing nothing.
-- precondition: (x1,y1) is in
-- bounds.
-- return whether the move
-- succeeded, i.e., there was
-- a specific interaction that
-- was performed.
function
move(x1,y1,x2,y2,dig)
 -- moving behaves a little
 -- differently depending on
 -- whether the destination is
 -- in bounds.
 local in_bounds2=
  0<=x2 and x2<board_width and
  0<=y2 and y2<board_height

 -- do nothing if either atom
 -- has been swapped this turn.
 if
  sget(x1+64,y1)~=0 or
  (in_bounds2 and
  sget(x2+64,y2)~=0)
 then
  return false
 end

 local atom1=sget(x1,y1)
 -- if atom2 is out of bounds,
 -- it's assumed to be of a
 -- specific type of atom.
 local atom2=
  in_bounds2 and
  sget(x2,y2) or
  out_of_bounds

 -- given the source atom and
 -- the destination atom,
 -- compute the atoms they turn
 -- into when the former i
 -- moved into the latter, or
 -- nil if there is no change.
 -- this relationship is not
 -- necessarily symmetric; even
 -- with the same two types of
 -- atom, moving one into the
 -- other doesn't necessarily do
 -- the same thing as the other
 -- way around.
 local new_atom1,new_atom2
 -- bugs can move through most
 -- things if actively digging.
 -- they may also lay eggs.
 if atom1==bug then
  if dig and atom2~=block then
   new_atom1,new_atom2=
    atom2==air and
    flr(rnd(120))==0 and
    egg or
    atom2,
    atom1
  elseif atom2==air then
   new_atom1,new_atom2=
    atom2,atom1
  end
 -- anything but plant moves
 -- through air.
 elseif
  atom2==air and
  atom1~=plant
 then
  new_atom1,new_atom2=
   atom2,atom1
 -- water and sand make clay.
 elseif
  (atom1==water and
   atom2==sand)
  or
  (atom1==sand and
   atom2==water)
 then
  new_atom1,new_atom2=air,clay
 -- oil rises on water.
 elseif
  atom1==water and
  atom2==oil
 then
  new_atom1,new_atom2=oil,water
 -- plant may consume water.
 elseif
  atom1==plant and
  atom2==water and
  flr(rnd(120))==0
 then
  new_atom1,new_atom2=
   plant,plant
 -- egg sinks in water.
 elseif
  atom1==egg and
  atom2==water
 then
  new_atom1,new_atom2=
   atom2,atom1
 end

 -- if there's no reaction, do
 -- nothing.
 if(new_atom1==nil)return false

 -- change the atoms and mark
 -- them as moved for the turn.
 sset(x1,y1,new_atom1)
 sset(x1+64,y1,1)
 -- the destination atom isn't
 -- changed if it's out of
 -- bounds.
 if in_bounds2 then
  sset(x2,y2,new_atom2)
  sset(x2+64,y2,1)
 end

 return true
end
-->8
-- options

-- each possible value for each
-- option consists of a label,
-- which is shown to the player
-- on the options screen, and a
-- value, which is the actual
-- lua value that the variable
-- corresponding to the option
-- will be set to.
-- labels are manually padded
-- to 6 characters because it
-- isn't worth writing a pad
-- function that parses the
-- formatting codes.
options={
 selected=1,
 {
  label='  atom',
  selected=1,
  {label=' \f5block',value= 5},
  {label='  \f4clay',value= 4},
  {label='  \ffsand',value=15},
  {
   label=' \#c\f1water',
   value=1,
  },
  {label='   \fdoil',value=13},
  {label=' \fbplant',value=11},
  {label='   \f6egg',value= 6},
 },
 {
  label=' brush',
  selected=1,
  {label='   1x1',value={1,1}},
  {label='   2x2',value={2,2}},
  {label='   4x4',value={4,4}},
  {label='   8x8',value={8,8}},
  {
   label='   row',
   value={board_width,1}
  },
  {
   label='column',
   value={1,board_height}
  },
 },
 {
  label='  draw',
  selected=1,
  {label='  over',value=true},
  {label=' under',value=false},
 },
 {
  label=' erase',
  selected=1,
  {label='  type',value=true},
  {label='   any',value=false},
 },
 {
  label='cursor',
  selected=1,
  {label='  fast',value=btn},
  {label='  slow',value=btnp},
 },
 {
  label='  time',
  selected=1,
  {label='  fast',value=1},
  {label='  slow',value=3},
  {label='  stop',value=nil
 },
 },
 {
  label='  edge',
  selected=1,
  {label='   \fcair',value=12},
  {label=' \f5block',value= 5},
 },
}

options_screen={}

function
options_screen.update()
 -- any button but an arrow
 -- returns to the simulation
 -- screen.
 if
  btn(🅾️) or
  btn(❎) or
  btn(6)
 then
  poke(0x5f30,1)
  update_options()
  set_screen(simulation_screen)
  return
 end

 -- ⬆️⬇️ change which option is
 -- being set.
 if(btnp(⬆️))change(options,-1)
 if(btnp(⬇️))change(options, 1)
 -- ⬅️➡️ change the selection
 -- for the current option.
 local option=
  options[options.selected]
 if(btnp(⬅️))change(option, -1)
 if(btnp(➡️))change(option,  1)
end

function
options_screen.draw()
 simulation_screen.draw()
 -- make a box on screen that's
 -- large enough to accommodate
 -- however many options there
 -- are, and centered.
 local w,h=80,8+(#options+4)*6
 local x,y=
  (128-w)/2,(128-h)/2
 camera(-x,-y)
 rectfill(-1,-1,w+1,h+1,1)
 rect(-1,-1,w+1,h+1,0)
 cursor(9,5)
 for option in all(options) do
  local selection=
   option[option.selected]
  print(
   option.label..
   '  '..
   selection.label,
   7
  )
 end
 print([[

(hold pause to
open the pico-8
pause menu.)
]], 7)
 print(
  '      <        >',
  9,5+(options.selected-1)*6,
  11
 )
 camera()
 clip()
end

-- set which selection the
-- given option is set to,
-- relative to the current
-- selection.
-- if the beginning or end of
-- the sequence is reached, it
-- wraps around.
function
change(option,amount)
 local length=#option
 option.selected=
  ((option.selected+amount-1)%
  length)+1
end

-- copy the values of all
-- options to the corresponding
-- variables.
-- this is done, rather than
-- using the options table
-- directly in the simulation
-- logic, because calling a
-- function and doing multiple
-- table lookups is slower than
-- referencing a single global
-- variable.
function
update_options()
 local o=options
 drawn_atom   =get_value(o[1])
 brush        =get_value(o[2])
 overdraw     =get_value(o[3])
 erase_type   =get_value(o[4])
 cursor_check =get_value(o[5])
 time_speed   =get_value(o[6])
 out_of_bounds=get_value(o[7])
end

-- get the value corresponding
-- to the current selection for
-- the given option.
function
get_value(option)
 return
  option[option.selected].value
end
__gfx__
ffffffffffffffffffffffffffffffff000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cffffffffffffffffffffffffffffffc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccffffffffffffffffffffffffffffcc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccffffffffffffffffffffffffffccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccccffffffffffffffffffffffffcccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccffffffffffffffffffffffccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccccccffffffffffffffffffffcccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccffffffffffffffffffccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccc5cc5cccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccccccc555cccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccc5cc5c555c5c5cccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccc55c5c5c5c555cccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccccccccccccccccccc5cccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccccccccccccccccc55ccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
c55555cccccccccccccccc5ccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccc5cccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccc5c555c55c55cc55c55c5c5c5c555c000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccc5c55cc5cc5cc5c5c5cc5c5c5c555c000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccc5c5ccc5cc5cc555c5cc5c5c5c5c5c000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
ccc5c555c5cc5cc5c5c5cc5c555c5c5c000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccc5c11111cc11111c5cccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
cccccccc5555555555555555cccccccc000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111
