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
  borders: struct {north, east, south, west : BorderKind},
  grid : [8][8]Cell,
}

BorderKind :: enum {
  Forest,
  Sea,
  Plain,
}

Cell :: enum {
  Nil,
}

Player :: struct {
  position_in_piece: Position,
}

Camera :: struct {
  game: ^Game,
}

// camera_to_screen