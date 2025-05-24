#+feature dynamic-literals

package domain

import "core:slice"

Game :: struct {
	m:      Map,
	player: Player,
}

Map :: struct {
	pieces: map[Position]Piece,
}

Position :: struct {
	x: i8,
	y: i8,
}

PIECE_EDGE_SIZE: u8 : 8

Piece :: struct {
	borders: struct {
		north, east, south, west: Biome,
	},
	grid:    [PIECE_EDGE_SIZE][PIECE_EDGE_SIZE]Cell,
}

// ┌─▻    clockwise
//   1 2 3        7 4 1
//   4 5 6    →   8 5 2
//   7 8 9        9 6 3
//       ◅─┘
rotate_piece_clockwise :: proc(using piece: Piece) {

}

Biome :: enum {
	Forest,
	Sea,
	Plain,
}

Cell :: enum {
	Nil,
	Ground,
	Tree,
	Rock,
}

Player :: struct {
	position_in_piece: Position,
}

Direction :: enum {
	None,
	Up,
	Down,
	Right,
	Left,
}

init_game :: proc() -> Game {
	spawn := Piece {
		borders = {
			north = Biome.Plain,
			east = Biome.Plain,
			south = Biome.Plain,
			west = Biome.Plain,
		},
	}

	slice.fill(spawn.grid[0][:], Cell.Ground)
	for &l in spawn.grid {
		for &c in l do c = Cell.Ground
	}

	return Game {
		m = {pieces = {{0, 0} = spawn}},
		player = {position_in_piece = {x = i8(PIECE_EDGE_SIZE) / 2, y = i8(PIECE_EDGE_SIZE) / 2}},
	}
}
