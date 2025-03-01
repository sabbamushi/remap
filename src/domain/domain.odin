#+feature dynamic-literals

package domain

Game :: struct {
  m: Map,
  player: Player,
}

Map :: struct {
  pieces : map[Position]Piece
}

Position :: struct {x: i8, y: i8}

PIECE_EDGE_SIZE :: 8

Piece :: struct {
  borders: struct {north, east, south, west : Biome},
  grid : [PIECE_EDGE_SIZE][PIECE_EDGE_SIZE]Cell,
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




init_game :: proc() -> Game {
  spawn := Piece{
    borders={
      north = Biome.Plain,
      east = Biome.Plain,
      south = Biome.Plain,
      west = Biome.Plain,
    }
  }

  return Game {
    m = {
      pieces = {
        {0,0} = spawn
      }
    },
    player = {
      position_in_piece = {x = PIECE_EDGE_SIZE/2, y = PIECE_EDGE_SIZE/2}
    }
  }
}
