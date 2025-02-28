package domain

Game :: struct {
  m: Map,
  player: Player,
}

Map :: struct {
  pieces : map[Position]Piece
}

Position :: struct {x: i8, y: i8}

Piece :: struct {
  borders: struct {north, east, south, west : Biome},
  grid : [8][8]Cell,
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

Camera :: struct {
  game: ^Game,
}

// camera_to_screen