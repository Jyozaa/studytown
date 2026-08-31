# StudyTown agent rules

- Read `ART_DIRECTION.md` before modifying visuals.
- The game intentionally uses a vibrant rather than muted palette.
- Do not introduce realistic human proportions.
- Do not reintroduce an island, town hub, or explorable overworld.
- The main menu directly selects study scenes.
- Exploration cameras remain fixed. Only focus mode uses camera changes.
- Every study spot needs explicit standing, sitting, rotation, animation, prop, and camera anchors.
- NPCs use explicit anchors or clear waypoint paths.
- The local character forward axis is +Z; use `yawForMovement` and never accept moonwalking.
- Prioritize composition and visual polish over technical breadth.
- Do not add character customization or multiplayer unless explicitly requested.
- Run typecheck, lint, tests, and build after behavioral changes.
