# CARTO-LIKE GAME DESIGN DOCUMENT

## Pitch

A puzzle game where the player manipulates a world map to solve puzzles and uncover a story exploring themes of adventure, discovery, and personal crisis.

### World Context

TODO

### Story Tone

Overall, the tone is light and contemplative, centered around adventure and discovery.  
However, there are also darker moments, times of acceleration and stress, and sometimes moments of emptiness.

## Core Mechanics

The player can move and rotate a piece of the world map to change the terrain in real-time. However, there are placement constraints: the edges of tiles must match in nature.  
For example, as in _Carto_, a forest cannot be placed adjacent to a desert.  
The edges of each map piece are associated with a specific terrain type (forest, desert, mountain, plains), and each piece can only be placed on tiles with compatible edges.

## Gameplay Loop

Explore → Modify the map → Talk to NPCs → Solve a puzzle → Unlock a new area → Find hidden objects or clues

## Main Game Systems

### Interactions

- Map

  - Move a map piece (up, down, left, right on a grid)
  - Rotate a map piece (clockwise and counterclockwise)
  - Constraints:
    - Map pieces cannot overlap.
      - A pleasant sound plays when a piece is correctly placed.
      - An error sound plays when a piece cannot be placed or moved.
    - Two pieces can only be placed next to each other if their edges are compatible (same terrain type).
      - A red line appears between two incompatible adjacent pieces.

- World
  - Move the player (up, down, left, right) until reaching a boundary.
  - Talk to an NPC.

### Puzzles & Obstacles

The puzzles are tied to the story. For example, in _Carto_, if an NPC mentions searching within the great forest, the player must assemble the map to form a single continuous forest containing all available pieces.

NPCs provide hints.

TODO: Create puzzles

### Player Progression

The player gradually unlocks new map pieces. The goal is to discover the entire map.  
Initially, it is preferable to have a single unified map rather than multiple independent zones like in _Carto_ (separate islands).

The difficulty increases progressively: puzzles become more complex, and new map pieces become harder to obtain.

Midway through the adventure, the character is lost, the path is no longer clear, and they must choose a direction randomly.  
The adventure represents life, incorporating aspects such as an existential crisis.

## Atmosphere & Art Direction

This game is in its very early stages, a minimalist version of [Carto](https://store.steampowered.com/app/1172450/Carto), at least regarding its main mechanic.  
The idea is to have storytelling more akin to [Braid](https://store.steampowered.com/app/26800/Braid) by Jonathan Blow, which is darker and more mature.

### Visual & Sound Inspirations

The visuals will depend significantly on the type and tone of the story.  
I love _Carto_'s visuals—very green, natural, and cozy.  
I also like pixel art styles like [Hyper Light Drifter](https://store.steampowered.com/app/257850/Hyper_Light_Drifter).  
To simplify development, the game will be in 2D and most likely in pixel art.

_Inside Out_ is an interesting inspiration since it explores human emotions.

TODO: Complete

### Examples of Graphic Styles or Moodboard

The world is a dreamlike universe composed of floating fragments in an infinite space, representing the protagonist's mind and emotional states.

TODO: Complete

## Narrative & Universe

### World Context

TODO

### Story Tone

Overall, a light and contemplative tone focused on adventure and discovery.  
However, there are darker moments, times of acceleration and stress, and sometimes moments of emptiness.

Most environmental elements serve as visual metaphors for emotions and the journey of life.

TODO: Develop further

### Key Characters

#### Main Character

TODO

#### NPCs

TODO

## MVP

A prototype featuring a modifiable map and the ability to unlock a new map piece.
