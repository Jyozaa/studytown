# StudyTown agent instructions

- FocusTown is a product, interaction, composition, and art-quality reference only. Never copy its proprietary assets, branding, source, or private APIs.
- Godot 4 remains the game engine; web export is a primary target; use GDScript and Compatibility rendering.
- There is no town/island overworld. Players choose authored rooms from the menu.
- Exploration cameras remain fixed and authored. Focus mode uses authored cinematic B-roll.
- Read `ART_DIRECTION.md` before visual changes.
- Prefer verified CC0 assets as raw material only for supporting content. Never assume free means CC0; update `ASSET_LICENSES.md` immediately.
- External assets must be visually normalized. Player characters are original hero assets.
- Character 01 is the master anatomy/hierarchy reference. Later characters derive from it.
- Master forward is local -Z. Use the centralized yaw formula; never accept backwards walking.
- Every StudySpot uses explicit standing/sitting transforms and camera data. NPCs use explicit anchors and paths.
- Visual polish takes priority over feature count. If Library screenshots look like a prototype, stop adding rooms and fix the Library. If characters look generic, fix the master.
- Perform screenshot-driven iteration and run the game before declaring visual work complete.
- Preserve the clean-room constraint and the retained CC0 license register.

