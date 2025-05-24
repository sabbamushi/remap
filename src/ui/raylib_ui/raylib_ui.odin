package raylib_ui

import "../../domain"
import "../../ui"
import "core:fmt"
import rl "vendor:raylib"

APP_NAME :: "REMAP"
WINDOW_RESOLUTION :: ui.Resolution{800, 450}
CELL_WIDTH_PX :: 16
GLOBAL_STATE: GlobalState
TARGET_FPS :: 30
SPEED :: 5 // pixels by frame -> Dtime ?

GlobalState :: struct {
    game:   domain.Game,
    camera: Camera,
    player: ui.Player,
}

Camera :: struct {
    game:     ^domain.Game,
    rlCamera: rl.Camera2D,
    // effects (colors, shader, etc)
}

main :: proc() {
    rl.InitWindow(
        i32(WINDOW_RESOLUTION.width),
        i32(WINDOW_RESOLUTION.height),
        APP_NAME,
    )
    rl.SetTargetFPS(TARGET_FPS)

    screen_center := get_resolution_center(WINDOW_RESOLUTION)
    player_resolution := ui.Resolution {
        width  = CELL_WIDTH_PX,
        height = 2 * CELL_WIDTH_PX,
    }
    GLOBAL_STATE = {
        game = domain.init_game(),
        player = {
            coordinate = {
                i16(piece_width() / 2) +
                screen_center.x -
                i16(player_resolution.width / 2),
                i16(piece_width() / 2) +
                screen_center.y -
                i16(player_resolution.height / 2),
            },
            resolution = player_resolution,
        },
    }

    GLOBAL_STATE.camera = {
        game     = &GLOBAL_STATE.game,
        rlCamera = build_camera(GLOBAL_STATE.player),
    }

    for !rl.WindowShouldClose() {
        direction := get_direction()
        player_move_to(&GLOBAL_STATE.player, direction)
        GLOBAL_STATE.camera.rlCamera = build_camera(GLOBAL_STATE.player)
        draw(GLOBAL_STATE.game)
    }

    rl.CloseWindow()
}

get_direction :: proc() -> domain.Direction {
    if rl.IsKeyDown(rl.KeyboardKey.UP) do return domain.Direction.Up
    if rl.IsKeyDown(rl.KeyboardKey.DOWN) do return domain.Direction.Down
    if rl.IsKeyDown(rl.KeyboardKey.LEFT) do return domain.Direction.Left
    if rl.IsKeyDown(rl.KeyboardKey.RIGHT) do return domain.Direction.Right
    return domain.Direction.None
}

player_move_to :: proc(p: ^ui.Player, d: domain.Direction) {
    using domain.Direction
    switch d {
    case Right: p.coordinate.x += SPEED
    case Left: p.coordinate.x -= SPEED
    case Up: p.coordinate.y -= SPEED
    case Down: p.coordinate.y += SPEED
    case None:
    }
}

draw :: proc(game: domain.Game) {
    rl.BeginDrawing()
    rl.ClearBackground(rl.WHITE)
    rl.BeginMode2D(GLOBAL_STATE.camera.rlCamera)

    p := GLOBAL_STATE.player
    center := get_resolution_center(WINDOW_RESOLUTION)

    for position, piece in game.m.pieces {
        c := ui.Coordinate {
            x = i16(position.x * i8(domain.PIECE_EDGE_SIZE) * CELL_WIDTH_PX),
            y = i16(position.y * i8(domain.PIECE_EDGE_SIZE) * CELL_WIDTH_PX),
        }
        draw_piece(piece, get_resolution_center(WINDOW_RESOLUTION))
    }

    rl.DrawRectangleRec(
        {
            f32(p.coordinate.x),
            f32(p.coordinate.y),
            f32(p.resolution.width),
            f32(p.resolution.height),
        },
        rl.RED,
    )

    rl.EndMode2D()
    rl.EndDrawing()
}

draw_piece :: proc(p: domain.Piece, c: ui.Coordinate) {
    width :: len(p.grid) * CELL_WIDTH_PX
    height :: len(p.grid[0]) * CELL_WIDTH_PX
    rl.DrawRectangle(i32(c.x), i32(c.y), i32(width), i32(height), rl.GREEN)
}

get_resolution_center :: proc(r: ui.Resolution) -> ui.Coordinate {
    return {x = i16(r.width / 2), y = i16(r.height / 2)}
}

coordinate_to_vector2 :: proc(c: ui.Coordinate) -> rl.Vector2 {
    return rl.Vector2{f32(c.x), f32(c.y)}
}

piece_width :: proc() -> u8 {
    return CELL_WIDTH_PX * domain.PIECE_EDGE_SIZE
}

build_camera :: proc(p: ui.Player) -> rl.Camera2D {
    screen_center := get_resolution_center(WINDOW_RESOLUTION)
    return {
        target = coordinate_to_vector2(p.coordinate),
        offset = coordinate_to_vector2(
            {
                x = screen_center.x - i16(p.resolution.width / 2),
                y = screen_center.y - i16(p.resolution.height / 2),
            },
        ),
        zoom = 1.0,
        rotation = 0.0,
    }
}
