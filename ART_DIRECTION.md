# StudyTown art direction

The visual target is a colourful cozy-console-life-sim diorama: chunky silhouettes, deliberately shaped characters, dense authored rooms, clean materials, warm light, and enough calm detail to leave the scene open through a long study block.

## Identity

StudyTown's signature is **storybook scholarship**: honey wood, cream paper, saturated book-spine colour, emerald foliage, teal upholstery, coral accents, expressive animal silhouettes, and large spaces discovered through a soft follow camera.

## Character rules

- Gameplay forward is always **-Z**. Imported source axes are corrected on `VisualRoot`; movement math never changes per character.
- Local development profiles use three distinct cat variants. Preserve their texture-based material personality and never flatten them into the procedural palette.
- `CharacterProfile` owns scale, visual offset, forward correction, collider dimensions, label height, animation map, and seating offset.
- The committed procedural character is a public fallback, not the intended hero path.
- Imported animation must match velocity: Idle at rest, Walk in motion, and no translated static models or moonwalking.

## Environment rules

- Every room needs foreground, midground, and background layers as the follow camera traverses it.
- Architecture has thickness, trim, framing, and integrated furniture. Camera-facing walls use intentional cutaways.
- Bookshelves are open-front constructions with backing, frame rails, shelf boards, irregular books, tilt, gaps, and several colours.
- Props are composed in small stories: laptop + mug + paper; book stack + lamp; armchairs + globe + plant.
- Registry-selected local props are preferred when present. CC0 Kenney and procedural assets remain coherent public fallbacks.
- Structural primitives remain appropriate for floors, walls, invisible boundaries, and collision—not as the default hero furniture language.

## Palette

Core: cream `#FFF4D6`, ink `#2D211C`, cocoa `#533528`, warm wood `#9F582D`, honey `#DC8E3D`.

Accents: leaf `#287847`, green `#3F8F58`, teal `#2F8F92`, blue `#4B73CB`, gold `#F3BD45`, coral `#ED755F`, red `#B9483E`, purple `#7F559F`.

## Material and light

- Wood is medium-rough with honey trim catching highlights; fabric is softer and rougher; paper is near-matte; ceramic is smoother; foliage is matte; glass is lightly metallic/smooth for Compatibility rendering.
- Use filmic tonemapping and warm key/fill separation. Do not flatten scenes with full ambient energy.
- Keep bloom subtle. Contact and furniture shadows do more grounding work than texture noise.

## Anti-goals

No floating-platform wide shots, grey boxes, chaotic NPC crowds, mouse-orbit camera, backwards walking, collisionless floors, or procedurally scattered clutter.
