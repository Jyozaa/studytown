# StudyTown art direction

The visual target is a colourful cozy-console-life-sim diorama: chunky silhouettes, deliberately shaped characters, dense authored rooms, clean materials, warm light, and enough calm detail to leave the scene open through a long study block.

## Identity

StudyTown's signature is **storybook scholarship**: honey wood, cream paper, saturated book-spine colour, emerald foliage, teal upholstery, coral accents, enormous expressive eyes, chunky sculpted hair, and intimate fixed-camera compositions.

## Character rules

- Master local forward is **-Z**. `atan2(-movement.x, -movement.z)` is the only gameplay facing convention.
- Head is 45–50% of silhouette height, wider than deep, with low facial features and pronounced cheek volume.
- Eyes always include white, coloured iris, pupil, and catchlight. Hair is made from a crown mass plus directional clumps that break the silhouette.
- Clothing changes the silhouette through a rounded sweater volume, contrasting hem, short sleeves, trousers, and thick-soled shoes.
- Later variants retain anatomy, anchors, and node hierarchy while changing skin, hair construction, palette, and accessory silhouette.

## Environment rules

- Every room needs foreground, midground, and background layers in the authored exploration camera.
- Architecture has thickness, trim, framing, and integrated furniture. Camera-facing walls use intentional cutaways.
- Bookshelves are open-front constructions with backing, frame rails, shelf boards, irregular books, tilt, gaps, and several colours.
- Props are composed in small stories: laptop + mug + paper; book stack + lamp; armchairs + globe + plant.
- Supporting CC0 assets are recoloured/re-scaled and used sparingly. Hero architecture, characters, fireplace, trees, and furniture language are original.

## Palette

Core: cream `#FFF4D6`, ink `#2D211C`, cocoa `#533528`, warm wood `#9F582D`, honey `#DC8E3D`.

Accents: leaf `#287847`, green `#3F8F58`, teal `#2F8F92`, blue `#4B73CB`, gold `#F3BD45`, coral `#ED755F`, red `#B9483E`, purple `#7F559F`.

## Material and light

- Wood is medium-rough with honey trim catching highlights; fabric is softer and rougher; paper is near-matte; ceramic is smoother; foliage is matte; glass is lightly metallic/smooth for Compatibility rendering.
- Use filmic tonemapping and warm key/fill separation. Do not flatten scenes with full ambient energy.
- Keep bloom subtle. Contact and furniture shadows do more grounding work than texture noise.

## Anti-goals

No floating-platform wide shots, grey boxes, capsule mannequins, pale monochrome rooms, empty bookshelves, corporate UI, mouse-orbit camera, or procedurally scattered clutter.

