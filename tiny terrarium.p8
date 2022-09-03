pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- tiny terrarium
-- by helado de brownie

-- this source code is designed
-- to be read in the pico-8
-- code editor. if you don't
-- otherwise have access to it,
-- try the education edition:
-- https://www.pico-8-edu.com/
-->8
-- style
-- this section describes the
-- stylistic conventions used
-- in the source code.

-- line length:
-- each line must be at most 31
-- columns wide. this means all
-- code can be read and written
-- without having to scroll the
-- screen horizontally. some
-- glyphs, such as 🅾️ and ❎,
-- are two columns wide; what
-- matters is the total width,
-- not the number of glyphs.

-- breaking lines:
-- lines may be broken after
-- symbols, such as = and +.
-- the part after the break
-- must be indented one more
-- place. if the line is broken
-- immediately after paired
-- syntax, the pair must be on
-- the same indent. e.g.:
--
--  print(foo + bar * baz)
--
--  print(foo +
--   bar * baz)
--
--  print(
--   foo + bar + baz
--  )

-- multi-line table literals:
-- when a table literal is
-- broken across lines, each
-- line should generally
-- correspond to one field,
-- which ends in a comma. this
-- means not having to edit
-- previous lines when adding
-- new fields. e.g.:
--
--  local t={
--   a=0,
--   b=1,
--   c=2,
--  }

-- function declarations:
-- a line break must go between
-- the function keyword and the
-- name of the function. this
-- ensures there's enough room
-- to comfortably fit the name
-- and parameters on the same
-- line in most cases. e.g.:
--
--  function
--  foo(argument1,argument2)
--   -- implementation
--  end
-->8
-- glossary
-- this section lists the terms
-- used in the source code and
-- in the game, in alphabetical
-- order.

-- atom:
-- an independently simulated
-- particle. every atom has an
-- element, which determines
-- how it behaves. atoms have
-- no identity; every atom of a
-- given element behaves the
-- same as every other. the
-- color of an atom is based
-- completely on its element.
-- atoms are just a convenient
-- abstraction; they aren't
-- represented directly. the
-- "movement" of an "atom" is
-- just the changing of the
-- element associated with one
-- or more tiles.

-- board:
-- the place where the
-- simulation happens. it takes
-- up the entire screen and is
-- a rectangular grid of tiles,
-- each of which contains
-- exactly one atom, no more or
-- less.

-- element:
-- a type of atom. the element
-- of an atom determines how it
-- behaves. these behaviors are
-- implemented in the
-- simulation_screen.update
-- function's main loop. each
-- element directly corresponds
-- to a unique pico-8 color, or
-- equivalently, an integer at
-- least 0 and less than 16.

-- move:
-- to move from a source tile
-- to a destination tile means
-- to attempt an interaction
-- between the atoms in those
-- tiles. the result of the
-- interaction is determined by
-- the source atom's element.
-- often, the result of a move
-- is that the tiles swap what
-- atoms are in them. this is
-- the case with clay and air,
-- for example. if there is no
-- specific interaction between
-- the two elements, the move
-- is said to fail, and the
-- atoms remain unchanged.

-- out of bounds (oob):
-- the area outside the board.
-- any coordinate that doesn't
-- correspond to a real tile is
-- out of bounds. oob atoms can
-- be interacted with but never
-- changed individually. all of
-- them can be changed at once
-- in the options.

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
-- this section describes the
-- strategies used to make the
-- game run at an acceptable
-- frame rate.

-- at a 32x32 board size, there
-- are 1024 atoms that need to
-- be simulated each frame.
-- this means there's very
-- little time to waste in the
-- simulation logic, which is
-- in simulation_screen.update.

-- the most important metric of
-- speed is cpu time. if the
-- game is over 100% cpu, then
-- it can't reliably capture
-- the pause button, which is
-- how the options screen is
-- accessed.

-- while in the game, press
-- ctrl+p to open the cpu
-- monitor. if the middle and
-- right numbers read as less
-- than 1.00, then the game is
-- running at an acceptable
-- speed.

-- the following strategies are
-- used to write code that uses
-- less cpu time.

-- cache global variables:
-- accessing global variables
-- is slower than doing so with
-- local ones. if a global is
-- to be used more than once in
-- a function, it can save time
-- to assign its value to a
-- local and use that instead.
-- if the global is a constant,
-- i.e., never needs to be
-- written back to, then
-- speeding up the code can be
-- as simple as, e.g.,
--
--  local air=air
--
-- without any other changes.

-- reuse information:
-- if the result of a check or
-- an expression is needed in
-- more than one place, compute
-- it once and then pass that
-- information on, e.g., by
-- passing it as an argument to
-- the function that needs it.
-- if even this would be too
-- expensive, design functions
-- so that they assume ahead of
-- time anything they need to,
-- and so don't need to check;
-- instead, the call site only
-- calls them if it's sure it's
-- safe to do so.

-- inline:
-- while writing functions as
-- separate units is extremely
-- useful for organization,
-- calling functions has a cost
-- that may not be worth the
-- performance tradeoff. in
-- these cases, and only in
-- these cases, consider taking
-- out any functions that are
-- too expensive and putting
-- their logic at the call
-- sites instead. in some cases
-- this may lead to duplicated
-- logic, which also incurs a
-- maintenance cost, so use
-- this sparingly.
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
fire1= 8 -- red
fire2= 9 -- orange
fire3=10 -- yellow
plant=11 -- light green
air  =12 -- light blue
oil  =13 -- lavender
bug  =14 -- pink
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

-- the element that will be
-- placed when the player
-- presses 🅾️.
-- valid values are all defined
-- elements.
draw_element=nil

-- the size of the area that
-- the player draws each frame.
-- valid values are sequences
-- of two positive integers no
-- larger than the respective
-- board dimensions.
brush=nil

-- if true, all elements except
-- bug will be overwritten by
-- drawing; otherwise, only air
-- will be.
-- valid values: true, false
overdraw=nil

-- if true, erasing only works
-- on the currently selected
-- element (draw_element).
-- valid values: true, false
erase_selected=nil

-- the function used to receive
-- input from the player.
-- example values: btn, btnp
get_input=nil

-- how fast the simulation
-- proceeds. larger is slower.
-- nil means time is stopped.
-- valid values are positive
-- integers and nil.
time_speed=nil

-- the element that fills the
-- out of bounds (oob) area.
-- oob atoms aren't affected by
-- time and can't individually
-- change, but in bounds atoms
-- can interact with them. see
-- the move function.
-- valid values are all defined
-- elements.
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

input_lock={}

function
btn_(b)
 local held=btn(b)
 if not held then
  input_lock[b]=nil
 end
 return
  held and
  not input_lock[b]
end

function
btnp_(b)
 local held=btnp(b)
 if not held then
  input_lock[b]=nil
 end
 return
  held and
  not input_lock[b]
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
 local fire1=fire1
 local fire2=fire2
 local fire3=fire3
 local plant=plant
 local oil=oil
 local bug=bug
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
   -- water falls straight down
   -- if able, or else moves
   -- left or right or stays
   -- still at random.
   -- it passes through air and
   -- oil, and combines with
   -- sand into clay.
   if atom==water then
    local function
    react(atom1,atom2)
     if
      atom2==air or
      atom2==oil
     then
      return atom2,atom1
     elseif atom2==sand then
      return air,clay
     end
    end
    if
     not move(x,y,x,y+1,react)
    then
     local side=flr(rnd(3))-1
     move(x,y,x+side,y,react)
    end
   -- oil falls straight down
   -- if able, or else moves
   -- left or right or stays
   -- still at random.
   -- it passes through air.
   elseif atom==oil then
    local function
    react(atom1,atom2)
     if atom2==air then
      return atom2,atom1
     end
    end

    if
     not move(x,y,x,y+1,react)
    then
     local side=flr(rnd(3))-1
     move(x,y,x+side,y,react)
    end
   -- egg falls straight down,
   -- left, or right at random,
   -- or may hatch.
   -- it passes through air,
   -- water, and oil.
   elseif atom==egg then
    local function
    react(atom1,atom2)
     if
      atom2==air or
      atom2==water or
      atom2==oil
     then
      return atom2,atom1
     end
    end

    local side=flr(rnd(3))-1
    local moved=
     move(x,y,x+side,y+1,react)
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
   -- it passes through air
   -- when falling, and
   -- anything but block when
   -- moving with purpose.
   elseif atom==bug then
    local function
    react_fall(atom1,atom2)
     if atom2==air then
      return atom2,atom1
     end
    end

    local function
    react_dig(atom1,atom2)
     if atom2==block then
      return
     end

     local atom2_=atom2
     if
      atom2==air and
      flr(rnd(120))==0
     then
      atom2_=egg
     end

     return atom2_,atom1
    end

    if
     not move(
      x,y,
      x,y+1,
      react_fall
     ) and
     flr(rnd(15))==0
    then
     local sidex=flr(rnd(3))-1
     local sidey=flr(rnd(3))-1
     move(
      x,y,
      x+sidex,y+sidey,
      react_dig
     )
    end
   -- plant may grow in a
   -- random direction if there
   -- is water there.
   elseif atom==plant then
    local function
    react(atom1,atom2)
     if
      atom2==water and
      flr(rnd(120))==0
     then
      return atom1,atom1
     end
    end

    local sidex=flr(rnd(3))-1
    local sidey=flr(rnd(3))-1
    move(
     x,y,
     x+sidex,y+sidey,
     react
    )
   -- clay falls straight down.
   elseif atom==clay then
    local function
    react(atom1,atom2)
     if
      atom2==air or
      atom2==water or
      atom2==oil
     then
      return atom2,atom1
     end
    end

    move(x,y,x,y+1,react)
   -- sand falls straight down,
   -- left, or right at random.
   elseif atom==sand then
    local function
    react(atom1,atom2)
     if
      atom2==air or
      atom2==oil
     then
      return atom2,atom1
     elseif atom2==water then
      return air,clay
     end
    end

    local side=flr(rnd(3))-1
    move(x,y,x+side,y+1,react)
   -- fire rises, sets things
   -- on fire, and may decay.
   elseif
    atom==fire3 or
    atom==fire2 or
    atom==fire1
   then
    local function
    react(atom1,atom2)
     if atom2==air then
      return atom2,atom1
     elseif
      atom2==plant or
      atom2==oil or
      atom2==egg or
      atom2==bug
     then
      return atom1,fire3
     end
    end

    local sidex=flr(rnd(3))-1
    local sidey=flr(rnd(3))-1
    local decay=flr(rnd(2))==0
    if decay then
     local atom_=atom-1
     if(atom_==7)atom_=air
     sset(x,y,atom_)
    end
    if
     sget(x+sidex,y+sidey)~=air
    then
     move(
      x,y,
      x+sidex,y+sidey,
      react
     )
    else
     move(
      x,y,
      x+sidex,y-1,
      react
     )
    end
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
 local btn=get_input
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
 -- - erase_selected is enabled
 --   and the atom is the same
 --   as the selected atom; or
 -- - erase_selected is
 --   disabled.
 local atom
 if(btn(🅾️))atom=draw_element
 if(btn(❎))atom=air
 if atom~=nil then
  for x=cx,cx+brw-1 do
   for y=cy,cy+brh-1 do
    local atom_here=sget(x,y)
    if(atom_here==bug)goto next
    if atom==air then
     if
      erase_selected and
      atom_here~=draw_element
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
move(x1,y1,x2,y2,react)
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

 -- use the supplied reaction
 -- logic to determine the
 -- result of the exchange.
 local new_atom1,new_atom2=
  react(atom1,atom2)

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
  label='element',
  selected=1,
  {
   label=' \f5block',
   value=block,
  },
  {
   label='  \f4clay',
   value=clay,
  },
  {
   label='  \ffsand',
   value=sand,
  },
  {
   label=' \#c\f1water',
   value=water,
  },
  {
   label='   \fdoil',
   value=oil,
  },
  {
   label=' \fbplant',
   value=plant,
  },
  {
   label='   \f6egg',
   value=egg,
  },
  {
   label='  \fafi\f9r\f8e',
   value=fire3,
  },
 },
 {
  label='  brush',
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
  label='   draw',
  selected=1,
  {label='  over',value=true},
  {label=' under',value=false},
 },
 {
  label='  erase',
  selected=1,
  {label='   any',value=false},
  {label='select',value=true},
 },
 {
  label=' cursor',
  selected=1,
  {label='  fast',value=btn_},
  {label='  slow',value=btnp_},
 },
 {
  label='   time',
  selected=1,
  {label='  fast',value=1},
  {label='  slow',value=3},
  {label='  stop',value=nil
 },
 },
 {
  label='   edge',
  selected=1,
  {label='   \fcair',value=12},
  {label=' \f5block',value= 5},
 },
}

options_screen={}

function
options_screen.update()
 -- 🅾️ and ❎ return to the
 -- simulation screen.
 local 🅾️_held=btn(🅾️)
 local ❎_held=btn(❎)
 if 🅾️_held or ❎_held then
  if 🅾️_held then
   input_lock[🅾️]=true
  end
  if ❎_held then
   input_lock[❎]=true
  end
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
 local w,h=84,8+(#options+6)*6
 local x,y=
  (128-w)/2,(128-h)/2
 camera(-x,-y)
 rectfill(-1,-1,w+1,h+1,1)
 rect(-1,-1,w+1,h+1,0)
 cursor(7,5)
 for option in all(options) do
  local selection=
   option[option.selected]
  print(
   option.label..
   '   '..
   selection.label,
   7
  )
 end
 print([[

(press pause
again to open
the pico-8 pause
menu, or 🅾️ or
❎ to go back.)
]], 7)
 print(
  '        <        >',
  7,5+(options.selected-1)*6,
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
 draw_element  =get_value(o[1])
 brush         =get_value(o[2])
 overdraw      =get_value(o[3])
 erase_selected=get_value(o[4])
 get_input     =get_value(o[5])
 time_speed    =get_value(o[6])
 out_of_bounds =get_value(o[7])
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
