# StudyTown agent instructions

- FocusTown is a product, interaction, composition, and art-quality reference only. Never copy its proprietary assets, branding, source, or private APIs.
- Godot 4 remains the game engine; web export is a primary target; use GDScript and Compatibility rendering.
- There is no town/island overworld. Players choose authored rooms from the menu.
- Exploration uses the smooth, approximately 45-degree elevated follow camera. Focus mode uses authored cinematic B-roll.
- Read `ART_DIRECTION.md` before visual changes.
- Owner-supplied local reference assets are not CC0. Never commit their meshes, textures, archives, extracted sources, derivatives, or screenshots.
- Use the metadata registry in `assets/local_asset_manifest.json` with ignored runtime files under `assets/dev_local/`, and always maintain runnable public fallback characters and props.
- Imported characters use `CharacterProfile` metadata for scene, scale, visual offset, forward correction, collider, animation map, seating offset, and label height.
- Master forward is local -Z. Use the centralized yaw formula; never accept backwards walking.
- Every StudySpot uses explicit standing/sitting transforms and camera data. NPCs use explicit anchors and paths.
- Retune StudySpots whenever furniture or character dimensions change.
- Every visible room floor requires a matching structural `StaticBody3D` floor collider. Never substitute constant downward velocity or disabled gravity for grounded physics.
- Rooms are intentionally large and socially populated. Current NPC targets are Library 6, Garden 5, Train 4, and Japanese Study Room 5; preserve quiet spacing and readable routes.
- Visual polish takes priority over feature count. If Library screenshots look like a prototype, stop adding rooms and fix the Library. If characters look generic, fix the master.
- Perform screenshot-driven iteration and run the game before declaring visual work complete.
- Preserve the clean-room constraint and the retained CC0 license register.
