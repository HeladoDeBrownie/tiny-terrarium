pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- tiny terrarium
-- by helado de brownie

-- this source code is designed
-- to be read in the pico-8
-- code editor. if you don't
-- otherwise have access to it,
-- try the education edition:
-- https://www.pico-8-edu.com/

-- the code is written
-- according to the following
-- style conventions.

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
-- atoms remain unchanged. an
-- atom that has already moved
-- this turn cannot move again.

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

-- each element *is* its color.
-- atoms contain no data other
-- than this.
air  =12 -- light blue
block= 5 -- dark gray
clay = 4 -- brown
sand =15 -- tan
water= 1 -- dark blue
oil  =13 -- lavender
plant=11 -- light green
egg  = 6 -- light gray
bug  =14 -- pink
fire3=10 -- yellow
fire2= 9 -- orange
fire1= 8 -- red
spout= 7 -- white

-- when the "spout" setting is
-- set to "random", these are
-- the elements that will be
-- emitted at random.
spoutables={
 block,
 clay,
 sand,
 water,
 oil,
 plant,
 egg,
 fire3,
}

-- when music mode is set to
-- "fun", these instruments
-- will play to represent the
-- given elements.
-- negative numbers are custom
-- instruments; add 8 to get
-- the actual index.
instruments={
 [air]  = 0, -- triangle
 [block]=-8,
 [clay] = 1, -- tilted saw
 [sand] =-4,
 [water]=-6,
 [oil]  =-7,
 [plant]= 5, -- organ
 [egg]  =-3,
 [bug]  =-5,
 [fire3]= 6, -- noise
 [fire2]= 6, -- noise
 [fire1]= 6, -- noise
 [spout]=-2,
}
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
-- although this is a no-op,
-- they are set to nil here to
-- make it clear that they
-- exist and are used.

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

-- the element that will be
-- generated by spout atoms.
-- valid values are all defined
-- elements, or nil for random.
spout_element=nil

-- whether and how to play
-- background music. the modes
-- are off, on, and fun mode.
-- if off, no music plays. if
-- on, the bgm plays with the
-- default instrumentation. if
-- fun mode, the voicing varies
-- based on what atoms are on
-- the board.
-- valid values are 0 for off,
-- 1 for on, and 2 for fun.
bgm_mode=nil

-- whether to play a sfx when
-- drawing or erasing.
-- valid values are true and
-- false.
sfx_mode=nil
-->8
-- setup

function
_init()
 -- load any saved options and
 -- begin on the simulation
 -- screen.
 cartdata'helado_tinyterrarium'
 update_options(false)
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

-- as a consequence of the
-- custom menu existing, it's
-- necessary to prevent button
-- presses from "leaking"
-- across screens. this is
-- handled by "locking" each
-- button until it's been
-- released at least once since
-- changing screens. look for
-- references to this variable
-- to see everywhere that needs
-- to be aware of this logic.
-- a more robust implementation
-- is possible, but was not
-- necessary for our purposes.
input_lock={}

-- btn_ and btnp_ behave just
-- like their namesakes btn and
-- btnp, except they are aware
-- of the input locking logic.

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
 local air=air
 local clay=clay
 local sand=sand
 local water=water
 local oil=oil
 local plant=plant
 local egg=egg
 local bug=bug
 local fire3=fire3
 local fire2=fire2
 local fire1=fire1
 local spout=spout
 local spoutables=spoutables
 local spout_element=
  spout_element

 -- slow time speed is handled
 -- by skipping simulation
 -- every so many frames. if
 -- time is stopped, simulation
 -- is always skipped. in any
 -- case, the player still gets
 -- to do things to the board
 -- afterwards.
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
     place(x,y,bug)
     sset(x+64,y,1)
    end
   -- spout stays in place but
   -- generates a certain
   -- element in a random
   -- adjacent tile, based on
   -- the spout setting.
   elseif atom==spout then
    local function
    react(atom1,atom2)
     if
      atom2~=spout and
      atom2~=bug and
      flr(rnd(10))==0
     then
      local to_spout=
       spout_element
      if to_spout==nil then
       local index=
        flr(rnd(#spoutables))+1
       to_spout=
        spoutables[index]
      end
      return atom1,to_spout
     end
    end

    local sidex=flr(rnd(3))-1
    local sidey=flr(rnd(3))-1
    move(
     x,y,
     x+sidex,y+sidey,
     react
    )
   -- bug falls straight down,
   -- or may move in a random
   -- direction. it may lay an
   -- egg if there's room.
   -- it passes through air
   -- when falling, and
   -- anything but block or
   -- spout when moving with
   -- purpose.
   elseif atom==bug then
    local function
    react_fall(atom1,atom2)
     if atom2==air then
      return atom2,atom1
     end
    end

    local function
    react_dig(atom1,atom2)
     if
      atom2==block or
      atom2==spout
     then
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
     place(x,y,atom_)
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
 local seeking=brush.seeking
 if(btn(⬅️))cx-=1
 if(btn(➡️))cx+=1
 if(btn(⬆️))cy-=1
 if(btn(⬇️))cy+=1
 cx,cy=
  mid(0,cx,bw-brw),
  mid(0,cy,bh-brh)
 cursor_x,cursor_y=cx,cy

 -- with the seeking brush,
 -- pressing 🅾️ or ❎ plays the
 -- bgm starting from the
 -- selected row.
 if seeking then
  if
   bgm_mode~=0 and
   (btn(🅾️) or btn(❎))
  then
   music(cy)
  end
  return
 end

 -- with the ordinary brushes,
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
 -- in addition, bug atoms are
 -- not removable either by
 -- drawing or erasing. they
 -- can however be removed by
 -- the simulation, such as by
 -- falling off the edge or
 -- being burned up.
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
    place(x,y,atom)
    ::next::
   end
  end
  if(sfx_mode)sfx(7)
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
 local seeking=brush.seeking
 local cw,ch=
  128/bw,128/bh
 -- compute screen position
 -- based on logical position
 -- and cursor size.
 local csx,csy=
  cursor_x*cw,cursor_y*ch
 -- draw it as a black outline
 -- if the normal cursor, or
 -- purple for the seeking one.
 rect(
  csx-1,csy-1,
  csx+cw*brw,csy+ch*brh,
  seeking and 2 or 0
 )

 -- if fun mode is on, indicate
 -- what note is playing by
 -- drawing a single dot on top
 -- of the corresponding tile.
 if bgm_mode==2 then
  local x,y=stat(50),stat(54)
  pset((x+0.5)*cw,(y+0.5)*ch,0)
 end
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
-- was performed. the move can
-- fail either because the
-- elements don't interact or
-- because one of the atoms has
-- already moved this turn.
-- element logic can use this
-- to try multiple behaviors in
-- sequence until one succeeds.
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
 -- has been moved this turn.
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
 place(x1,y1,new_atom1)
 sset(x1+64,y1,1)
 -- the destination atom isn't
 -- changed if it's out of
 -- bounds.
 if in_bounds2 then
  place(x2,y2,new_atom2)
  sset(x2+64,y2,1)
 end

 return true
end

function
place(x,y,new_atom)
 sset(x,y,new_atom)
 -- if fun mode is active, also
 -- update the music state.
 if bgm_mode==2 then
  update_bgm(x,y,x,y)
 end
end

-- in the given rectangular
-- region of the board, change
-- the instrument of the bass
-- note corresponding to each
-- tile to an instrument that's
-- determined by what atom is
-- occupying that tile. see
-- the instruments constant
-- for what maps onto what.
function
update_bgm(x0,y0,x1,y1)
 local instruments=instruments
 for x=x0,x1 do
  for y=y0,y1 do
   local atom=sget(x,y)
   local instrument=
    instruments[atom] or 0
   local custom=0
   if instrument<0 then
    instrument+=8
    custom=0b1000000000000000
   end
   local track=32+y
   local address=
    0x3200+track*68+x*2
   local data1=peek2(address)
   local data2=
    data1
     &0b0111111000111111
     |(instrument<<6)
     |custom
   poke2(address,data2)
  end
 end
end
-->8
-- options

-- each possible value for each
-- option consists of a label,
-- which is shown to the player
-- on the options screen, and a
-- value, which is the actual
-- lua value corresponding to
-- that selection.
-- labels are manually padded
-- to 6 characters because it
-- isn't worth writing a pad
-- function that parses the
-- formatting codes.
-- each option also has a
-- function that must be run to
-- update relevant game state.
-- this is done, rather than
-- using the options table
-- directly in the simulation
-- logic, because calling a
-- function and doing multiple
-- table lookups is slower than
-- referencing a single global
-- variable.
options={
 selected=1,
 {
  label='element',
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
  {
   label=' \f7spout',
   value=spout,
  },
  update=function(value)
   draw_element=value
  end,
 },
 {
  label='  brush',
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
  {
   label='  seek',
   value={
    seeking=true,
    board_width,1,
   }
  },
  update=function(value)
   brush=value
  end,
 },
 {
  label='   draw',
  {label='  over',value=true},
  {label=' under',value=false},
  update=function(value)
   overdraw=value
  end,
 },
 {
  label='  erase',
  {label='   any',value=false},
  {label='select',value=true},
  update=function(value)
   erase_selected=value
  end,
 },
 {
  label=' cursor',
  {label='  fast',value=btn_},
  {label='  slow',value=btnp_},
  update=function(value)
   get_input=value
  end,
 },
 {
  label='   time',
  {label='  fast',value=1},
  {label='  slow',value=3},
  {label='slooow',value=9},
  {label='  stop',value=nil},
  update=function(value)
   time_speed=value
  end,
 },
 {
  label='   edge',
  {
   label='   \fcair',
   value=air,
  },
  {
   label=' \f5block',
   value=block,
  },
  {
   label=' \#c\f1water',
   value=water,
  },
  update=function(value)
   out_of_bounds=value
  end,
 },
 {
  label='  spout',
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
  {
   label=
    '\f8r\f9a\fan\f3d\fco\fdm',
   value=nil,
  },
  update=function(value)
   spout_element=value
  end,
 },
 {
  label='  music',
  {label='    on',value=1},
  {label='   fun',value=2},
  {label='   off',value=0},
  update=function(value)
   -- silence the bgm if it was
   -- just turned off.
   if value==0 then
    music(-1)
   -- start playing the bgm if
   -- it was not playing.
   elseif stat(54)==-1 then
    music(0)
   end

   -- fun mode is now active.
   -- change the instruments
   -- based on the whole board.
   if value==2 then
    update_bgm(
     0,0,
     board_width,board_height
    )
   -- fun mode is not active.
   -- revert the instrument
   -- changes.
   else
    reload(
     -- ram offset to copy to
     0x3200,
     -- rom offset to copy from
     0x3200,
     -- how much to copy
     0x1100
    )
   end
   bgm_mode=value
  end,
  immediate=true,
 },
 {
  label='    sfx',
  {label='    on',value=true},
  {label='   off',value=false},
  update=function(value)
   sfx_mode=value
  end,
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
  update_options(true)
  set_screen(simulation_screen)
  return
 end

 -- ⬆️⬇️ change which option is
 -- being set.
 local dy=0
 if(btnp(⬆️))dy=-1
 if(btnp(⬇️))dy= 1
 options.selected=
  (options.selected+dy-1)%
  #options+1
 -- ⬅️➡️ change the selection
 -- for the current option.
 local index=options.selected
 local dx=0
 if(btnp(⬅️))dx=-1
 if(btnp(➡️))dx= 1
 if (dx==0) return
 local option=options[index]
 dset(index-1,
  (dget(index-1)+dx)%#option)
 if option.immediate then
  option.update(
   get_option(index).value
  )
 end
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
 for index,option in
  ipairs(options)
 do
  local selection=
   get_option(index)
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

-- do update logic for all the
-- options.
-- an immediate option is one
-- that does its update logic
-- as soon as it changes. pass
-- true if immediate options
-- are already up to date, or
-- false if they need to be
-- updated. the latter is the
-- case at cart startup.
function
update_options(skip_immediate)
 for index,option in
  ipairs(options)
 do
  if
   not skip_immediate or
   not option.immediate
  then
   option.update(
    get_option(index).value
   )
  end
 end
end

-- get the value corresponding
-- to the current selection for
-- the option at the given
-- index. the current selection
-- is read from the persistent
-- cart data section of memory.
function
get_option(index)
 local option=options[index]
 local selection=
  flr(dget(index-1)+1-1)%
  #option+1
 return option[selection]
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
__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccc
ccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccc
ccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccc
ccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccc
ccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccc
ccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccc
ccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccc
ccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccc
ccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccc
ccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccc
ccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccc
ccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccc
ccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccc
ccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccc
ccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccc
ccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccc
ccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccc
ccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccc
ccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccc
ccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccc
ccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccc
ccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccc
ccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccc
ccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccc
ccccccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc55555555cccc5555cccc5555cccc5555cccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc55555555cccc5555cccc5555cccc5555cccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc55555555cccc5555cccc5555cccc5555cccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc55555555cccc5555cccc5555cccc5555cccc555555555555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555cccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555cccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555cccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc0000005555555cccccccccccccccccccccccccccccccccccccccccccccccccccc
cccc55555555555555555555ccccccccccccccccccccccccccccccccccccccc0ffff0ccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccc
cccc55555555555555555555ccccccccccccccccccccccccccccccccccccccc0ffff0ccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccc
cccc55555555555555555555ccccccccccccccccccccccccccccccccccccccc0ffff0ccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccc
cccc55555555555555555555ccccccccccccccccccccccccccccccccccccccc0ffff0ccccccccccccccccccc5555cccccccccccccccccccccccccccccccccccc
cccccccccccc5555ccccccccccccccccccccccccccccccccccccccccccccccc000000ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccc5555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccc5555cccc555555555555cccc55555555cccc55555555cccccccc55555555cccc55555555cccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc555555555555cccc55555555cccc55555555cccccccc55555555cccc55555555cccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc555555555555cccc55555555cccc55555555cccccccc55555555cccc55555555cccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc555555555555cccc55555555cccc55555555cccccccc55555555cccc55555555cccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc55555555cccccccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc55555555cccccccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc55555555cccccccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc55555555cccccccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc5555cccc5555cccc555555555555cccc
cccccccccccc5555cccc5555cccccccccccc5555cccccccc5555cccccccc555555555555cccc5555cccccccc5555cccc5555cccc5555cccc5555cccc5555cccc
cccccccccccc5555cccc5555cccccccccccc5555cccccccc5555cccccccc555555555555cccc5555cccccccc5555cccc5555cccc5555cccc5555cccc5555cccc
cccccccccccc5555cccc5555cccccccccccc5555cccccccc5555cccccccc555555555555cccc5555cccccccc5555cccc5555cccc5555cccc5555cccc5555cccc
cccccccccccc5555cccc5555cccccccccccc5555cccccccc5555cccccccc555555555555cccc5555cccccccc5555cccc5555cccc5555cccc5555cccc5555cccc
cccccccccccc5555cccc555555555555cccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccc
cccccccccccc5555cccc555555555555cccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccc
cccccccccccc5555cccc555555555555cccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccc
cccccccccccc5555cccc555555555555cccc5555cccccccc5555cccccccc5555cccc5555cccc5555cccccccc5555cccc555555555555cccc5555cccc5555cccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccc11111111111111111111cccccccc11111111111111111111cccc5555cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccc11111111111111111111cccccccc11111111111111111111cccc5555cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccc11111111111111111111cccccccc11111111111111111111cccc5555cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555cccc11111111111111111111cccccccc11111111111111111111cccc5555cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555555555555555555555555555555555555555555555555555555555555555cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555555555555555555555555555555555555555555555555555555555555555cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555555555555555555555555555555555555555555555555555555555555555cccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc5555555555555555555555555555555555555555555555555555555555555555cccccccccccccccccccccccccccccccc

__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400041877718007187771800700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
600800041807018000180601800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040005247711877124771187710c771007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000200001835218072180721807218062180621805218052180421804218032180321802218022180121801200000000000000000000000000000000000000000000000000000000000000000000000000000000
90040005243211872124721187210c721007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000100011835000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001f7131c713187130070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703
0120000023740237412374123741237312373123721237212371123711237112371121740217411f7402174021741217412174121741217312173121721217212171121711217112171121740217411f7401d740
012000001d7401d7411d7411d7411c7401c7411d7401f7401f7411f7411f7411f7411d7401d7411c7451c7401c7411c7411c7411c7411c7311c7311c7211c7211c7111c7111c7111c71100700007000070018740
012000001d7401d7411d7411d7451d7401d7412474023740237412374123741237452374023741247452474024741247412474124741247312473124721247212471124711247112471100000000000000000000
012000002674028740267402674126741267412673126731267212672126711267152674024745247402374523741237412374123741237312373123721237212371123711237112371124740247412374021740
012000002174021741217412174121731217311f74021740237402374123741237412373123731247402374021740217412174121741217312173121721217212171121711217112171100000000000000000000
012000002174021741217412174121731217311f7402174023740237412374123741237312373121740237402474024741247412474124731247312374024740267402674126741267411f7401f7412b7402b741
012000002974029741297412974128740287412674026741287402874128741287412873128731287212872128711287112871128711007000070000700007000070000700007000070000700007000070000700
012000001d7401d7411d7411d7451d7401d7412474023740237412374123741237452374023741217452174021741217412174121741217312173121721217212171121711217112171521740217411f7401d740
012000001d7401d7411d7411d7451d7401d7412474023740237412374123741237452374023741247452474024741247412474124741247312473124721247212471124711247112471121700217001f7001d700
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b05507055040550005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b0550005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b055090550c05510055130551505513055100550c0550b0550e05511055150551705515055110550e055
192000000005500055000550005507055070550705507055000550405500055040550004504045000450404500035040350003504035000250402500025040250001504015000150401500015040150001504015
192000000005004050070500b0500c0500b05007050040500005004050070500b0500c0500b05007050040500005004050070500b0500c0500b05007050040500005004050070500b0500c0500b0500705004050
192000000005004050070500b0500c0500b05007050040500005004050070500b0500c0500b0500705004050090500c05010050130501505013050100500c050090500c05010050130501505013050100500c050
1920000005050090500c0501005011050100500c05009050070500b0500e0501105013050110500e0500b050090500c05010050130501505013050100500c050090500c05010050130501505013050100500c050
1920000005050090500c0501005011050100500c05009050070500b0500e0501105013050110500e0500b050090500c05010050130501505013050100500c050090500c05010050130501505013050100500c050
1920000005050090500c0501005011050100500c05009050070500b0500e0501105013050110500e0500b050000500405007050080500c050080500705004050000500405007050080500c050080500705004050
192000000005004050070500b0500c050100501305017050180501705013050100500c0500b05007050040500005004050070500b0500c050100501305017050180501705013050100500c0500b0500705004050
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b05507055040550005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b0550005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
192000000005504055070550b0550c0550b05507055040550005504055070550b0550c0550b0550705504055090550c05510055130551505513055100550c055090550c05510055130551505513055100550c055
1920000005055090550c0551005511055100550c05509055070550b0550e0551105513055110550e0550b055090550c05510055130551505513055100550c0550b0550e05511055150551705515055110550e055
192000000005500055000550005507055070550705507055000550405500055040550004504045000450404500035040350003504035000250402500025040250001504015000150401500015040150001504015
192000000005004050070500b0500c0500b05007050040500005004050070500b0500c0500b05007050040500005004050070500b0500c0500b05007050040500005004050070500b0500c0500b0500705004050
192000000005004050070500b0500c0500b05007050040500005004050070500b0500c0500b0500705004050090500c05010050130501505013050100500c050090500c05010050130501505013050100500c050
1920000005050090500c0501005011050100500c05009050070500b0500e0501105013050110500e0500b050090500c05010050130501505013050100500c050090500c05010050130501505013050100500c050
1920000005050090500c0501005011050100500c05009050070500b0500e0501105013050110500e0500b050090500c05010050130501505013050100500c050090500c05010050130501505013050100500c050
1920000005050090500c0501005011050100500c05009050070500b0500e0501105013050110500e0500b050000500405007050080500c050080500705004050000500405007050080500c050080500705004050
192000000005004050070500b0500c050100501305017050180501705013050100500c0500b05007050040500005004050070500b0500c050100501305017050180501705013050100500c0500b0500705004050
__music__
01 20404040
00 21084040
00 22094040
00 23084040
00 240a4040
00 250b4040
00 260c4040
00 270b4040
00 280d4040
00 290e4040
00 2a404040
00 2b084040
00 2c0f4040
00 2d0f4040
00 2e104040
00 2f404040
00 30404040
00 31084040
00 32094040
00 33084040
00 340a4040
00 350b4040
00 360c4040
00 370b4040
00 380d4040
00 390e4040
00 3a404040
00 3b084040
00 3c0f4040
00 3d0f4040
00 3e104040
02 3f404040

