# StudyTown art direction

## Reference observations

The supplied references succeed through warm, saturated colour, rounded toy-like geometry, clean silhouettes, and carefully layered diorama compositions. Characters have heads that occupy roughly half their height, tiny torsos and legs, large readable eyes, chunky shoes, and sculptural hair clumps. They read as friendly life-sim toys rather than miniature realistic people.

The environments use foreground framing, active midgrounds, and decorative backgrounds. Books, flowers, cushions, lamps, plants, stationery, and furniture fill nearly every zone without destroying walkable clarity. Warm orange woods sit against clear teal blues, fresh greens, golden light, and small high-chroma accents. The Library references pair cool window light with the fireplace; the garden uses flowers to break up grass; the train reference suggests a miniature journey rather than a sterile carriage.

The exploration view is a composed, elevated fixed camera. Rooms should feel like dollhouses, with two sides open to the viewer and controlled boundaries. Focus mode alone changes the camera, using authored B-roll rather than an orbit.

## Palette and material rules

`src/game/palette.ts` is canonical. Use saturated warm wood, orange brick, cream, fresh/deep leafy greens, clear sky/water blues, and distinct red/blue/green/yellow books. Toon materials, soft directional light, hemispheric fill, contact shadows, bevels, and rounded silhouettes create depth. Never flatten the world to pale pastels or photorealistic textures.

## Scale

- Character: 1.9 world units; head center at 1.46, ~46% of silhouette.
- Chair seat: 0.47–0.56 units.
- Desk top: 0.9 units.
- Standard wall: 4.6–6 units.
- Train seat: 0.5–0.56 unit seat height.
- Local character forward axis: **+Z**. `yawForMovement(x,z) = atan2(x,z)` is the single orientation convention.

Study anchors use the seat height rather than furniture origins. Green is standing, blue sitting, and yellow camera target in developer mode.
