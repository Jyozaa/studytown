# Reference analysis

StudyTown is a clean-room implementation. FocusTown was inspected on 1 September 2026 only as a product, interaction, composition, and quality reference. No proprietary source, network API, model, texture, sound, icon, copy, or brand asset was extracted.

## Observed composition

- The live Boston Library uses a fixed perspective camera approximately 50–60° downward, with modest perspective rather than orthographic projection. The room is framed edge to edge and reads like a dollhouse interior.
- The player occupies roughly 8–11% of the viewport height in exploration. Heads are close to half of visible character height. Hair and headwear do most of the silhouette work.
- Tables form a regular central rhythm while tall shelves wrap the perimeter. Approximately 70–80% of visible floor is occupied by a circulation route, rug pattern, furniture, or a character; there is little uncomposed empty space.
- Foreground shelf/chair edges create depth, occupied study tables form the midground, and book-filled walls/windows form the background.
- The strongest live-library view uses a steep camera and controlled room boundary. Walls are visually cropped; the scene does not sit on a widely visible floating platform.

## Scale specification

- StudyTown master character: 2.75–2.9 m visual height in the deliberately toy-like world scale; head approximately 48% of silhouette height.
- Standard desk surface: 1.05–1.2 world units high. Seat surface: approximately 0.7 units. These values are paired with explicit StudySpot anchors.
- Typical desk width is 3.5–3.8 units, allowing the broad character to remain readable beside props.

## Character and social readability

- Reference characters favor extremely wide heads, short limbs, simple clothing blocks, and unmistakable hair/headwear.
- Faces must survive a steep gameplay camera. StudyTown therefore uses layered eye white, iris, pupil, catchlight, a low face placement, and a small mouth—not two black dots.
- Compact floating identity labels carry a name and remaining time. Social state is visible without opening a chat surface.
- Seated characters are the dominant population state. Empty chairs are bright/readable and occupied seats alternate around tables to avoid a solid crowd wall.

## Colour, material, and light

- The reference library is warm and dark: red-brown shelves, honey table highlights, cream window light, a patterned brown floor, and saturated book spines.
- Saturation is concentrated in books, lamps, clothes, and foliage. StudyTown expands that range with teal, coral, green, blue, gold, red, and purple.
- Lighting has strong warm highlights and deep shelf recesses. StudyTown uses filmic tonemapping, warm directional/key light, soft ambient fill, local fireplace light, shadows, low bloom, and roughness differences among fabric, paper, wood, foliage, glass, and ceramic.

## UI and flow

- The live product separates place discovery from the room itself. Place cards include a rendered preview, place name, availability/social count, and one dominant action.
- In-room UI hugs corners and leaves the 3D centre open. A compact player/activity panel can expand without permanently covering the room.
- StudyTown keeps room selection on the title screen, uses a single nearby interaction prompt, and replaces exploration chrome with one calm focus card during a session.
- Timer typography must be the largest element of the focus card. Task, place, focus state, and End Session remain secondary.

## StudyTown design response

- Exploration camera: fixed, 39–41° FOV, elevated three-quarter view; no orbit and no follow camera.
- Focus mode: a spot-specific personal view followed by 4–7 authored room B-roll cameras, changing every 25 seconds without continuous orbit.
- Library: built-in shelves, hundreds of varied book spines, thick moulding, window framing, hero fireplace, layered reading nook, rugs, plants, desk clutter, and six seated students.
- UI: cream paper surfaces, cocoa ink, honey borders, rounded game-like cards, restrained shadows, and no SaaS-dashboard visual language.

