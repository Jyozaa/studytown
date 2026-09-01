# ACNH character diagnostics

The owner-supplied Alligators / Crocodiles archive was inspected in Blender 5.2 before integration. These records describe local development inputs; they do not redistribute them.

## Alfonso

- Mesh: yes; base body, mouth, and T-shirt layers selected from the archive
- Textures: yes; body, beak, clothing, and eye albedo maps
- Armature: yes, 48 bones
- Embedded animation actions: none
- Generated local prototype clips: Idle, Walk, Sit, StudyLaptop, StudyBook, Wave, Stretch
- Source forward: +Z; normalized to gameplay -Z by `VisualRoot`
- Recommended Godot scale: 5.7

## Gayle

- Mesh: yes; compatible shared alligator rig and mesh
- Textures: yes; Gayle-specific body, beak, clothing, and eye maps
- Armature: yes, 48 bones
- Embedded animation actions: none
- Generated local prototype clips: Idle, Walk, Sit, StudyLaptop, StudyBook, Wave, Stretch
- Source forward: +Z; normalized to gameplay -Z by `VisualRoot`
- Recommended Godot scale: 5.7

## Drago

- Mesh: yes; dedicated Drago body/mouth source plus compatible T-shirt
- Textures: yes; Drago-specific body, beak, clothing, and eye maps
- Armature: yes, 48 bones
- Embedded animation actions: none
- Generated local prototype clips: Idle, Walk, Sit, StudyLaptop, StudyBook, Wave, Stretch
- Source forward: +Z; normalized to gameplay -Z by `VisualRoot`
- Recommended Godot scale: 5.7

All actions require in-game deformation and seat-contact review. The manifest keeps collider, visual, label, forward-axis, and seating metadata per character so these values can diverge safely if later species use incompatible skeletons.
