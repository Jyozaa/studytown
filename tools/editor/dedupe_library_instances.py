#!/usr/bin/env python3
"""Remove baked duplicate instance-children from library.tscn.

Root cause: the room baker stamps owner=layout on GLB instance children, so
PackedScene.pack persists them as local overrides. At load, each instance
spawns its GLB children PLUS the same-name explicit siblings; one twin ends
up out-of-tree (is_inside_tree errors, wrong seat-mesh binding, dead nodes).

This keeps the pure `instance=` roots and deletes only explicit descendants
that duplicate GLB-provided content (verified identical: builders only ever
transform instance roots). Friction-tuned nodes (cast_shadow etc. on direct
KayKit children) are intentionally preserved.

Run after every library rebake:
    python3 tools/editor/dedupe_library_instances.py
"""
import re
import sys

PATH = "assets/dev_local/room_layouts/library.tscn"

# Explicit descendants that duplicate GLB content (name -> must be nested
# under an instance root). Depth-1 inners and their books, car wheels,
# fridge doors.
DUP_NAMES = {
    "StudyTown_bookshelf",
    "Book10_low__mReBody",
    "car_sedan_wheel_front_left",
    "car_sedan_wheel_front_right",
    "car_sedan_wheel_rear_left",
    "car_sedan_wheel_rear_right",
    "car_hatchback_wheel_front_left",
    "car_hatchback_wheel_front_right",
    "car_hatchback_wheel_rear_left",
    "car_hatchback_wheel_rear_right",
    "fridge_A_decorated_door_bottom",
    "fridge_A_decorated_door_top",
}


def main() -> None:
    src = open(PATH).read()
    parts = re.split(r"(?m)(?=^\[)", src)
    inst_roots = set()
    for part in parts:
        m = re.match(r'\[node name="([^"]+)"[^]]*parent="\."[^\]]*instance=ExtResource', part)
        if m:
            inst_roots.add(m.group(1))
    out = []
    deleted = []
    for part in parts:
        m = re.match(r'\[node name="([^"]+)"[^]]*parent="([^"]*)"', part)
        if m and m.group(1) in DUP_NAMES and m.group(2).split("/")[0] in inst_roots:
            deleted.append(m.group(1))
            continue
        out.append(part)
    open(PATH, "w").write("".join(out))
    from collections import Counter
    print("dedupe: instance roots:", len(inst_roots))
    print("dedupe: deleted:", len(deleted), Counter(deleted))


if __name__ == "__main__":
    main()
