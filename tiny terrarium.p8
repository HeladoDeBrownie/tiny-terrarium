pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
-- tiny terrarium
-- by helado de brownie

-- this source code is best
-- read in the pico-8 code
-- editor or else in a
-- programming text editor with
-- tab width set to 1. try the
-- education edition if you
-- don't have access to it
-- otherwise:
-- https://www.pico-8-edu.com/

-- because of the limited
-- visible line length, lines
-- are broken after 15
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
-- the bump function.

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
-- 	local air=air

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

-- the out of bounds area can't
-- change but it's assumed to
-- be full of a specific atom.
-- in bounds atoms can react to
-- it; see the move and bump
-- functions.
out_of_bounds=air
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

cursor_x,cursor_y=0,0
selected_atom=sand
-->8
-- functions

-- move the atom at (x1,y1) to
-- (x2,y2). the result of this
-- depends on the interactions
-- specified by the bump
-- function, but broadly
-- speaking either ends up
-- changing the two atoms or
-- doing nothing.
-- precondition: (x1,y1) is in
-- bounds.
-- return whether the move
-- succeeded, i.e., the bump
-- function specified an
-- interaction and it was done.
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

	-- determine what the atoms
	-- change into.
	local new_atom1,new_atom2=
		bump(atom1,atom2,dig)

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

-- given a source atom and a
-- destination atom, return the
-- atoms they turn into when
-- the former is moved into
-- the latter, or nil if there
-- is no change.
-- this relationship is not
-- necessarily symmetric; even
-- with the same two types of
-- atom, moving one into the
-- other doesn't necessarily do
-- the same thing as the other
-- way around.
function
bump(atom1,atom2,dig)
	-- bugs can move through most
	-- things if actively digging.
	-- they may also lay eggs.
	if atom1==bug then
		if dig and atom2~=block then
			return
				atom2==air and
				flr(rnd(120))==0 and
				egg or
				atom2,
				atom1
		elseif atom2==air then
			return atom2,atom1
		end
	-- anything moves through air.
	elseif atom2==air then
		return atom2,atom1
	-- water and sand make clay.
	elseif
		(atom1==water and
		 atom2==sand)
		or
		(atom1==sand and
		 atom2==water)
	then
		return air,clay
	-- oil rises on water.
	elseif
		atom1==water and
		atom2==oil
	then
		return oil,water
	elseif
		atom1==water and
		atom2==plant and
		flr(rnd(120))==0
	then
		return plant,plant
	end
end
-->8
-- hooks

function
_update()
	local bw,bh=
		board_width,board_height
	local water=water
	local clay=clay
	local egg=egg
	local bug=bug
	local oil=oil
	local sand=sand

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

	-- respond to user input.
	-- ⬅️➡️⬆️⬇️ move the cursor.
	local cx,cy=cursor_x,cursor_y
	if(btn(⬅️))cx-=1
	if(btn(➡️))cx+=1
	if(btn(⬆️))cy-=1
	if(btn(⬇️))cy+=1
	cx,cy=
		mid(0,cx,bw-1),
		mid(0,cy,bh-1)
	cursor_x,cursor_y=cx,cy
	-- 🅾️ replaces the atom under
	-- the cursor with the
	-- selected atom, unless it
	-- would replace bug.
	if
		btn(🅾️)
		and sget(cx,cy)~=bug
	then
		sset(cx,cy,selected_atom)
	end
end

function
_draw()
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
	-- compute width and height
	-- based on screen and board
	-- sizes.
	local cw,ch=128/bw,128/bh
	-- compute screen position
	-- based on logical position
	-- and cursor size.
	local csx,csy=
		cursor_x*cw,cursor_y*ch
	-- draw it as a black outline.
	rect(
		csx,csy,
		csx+cw,csy+ch,
		0
	)
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
