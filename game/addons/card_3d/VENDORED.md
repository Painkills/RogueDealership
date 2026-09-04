# Card3D — vendored, not a dependency

Source: <https://github.com/tdecker91/Card3D>
Commit: `c37695d8c8381a25a266ed59284e77a2b00676b5`
Vendored: 2026-09-03
License: MIT (see `LICENSE` in this directory)

Copied verbatim from the upstream `addons/card_3d/` directory. **Do not edit these files.**
Everything this game needs is done by extending them from `res://scripts/view/` and
`res://scenes/`, so that re-vendoring a newer upstream is a directory replacement rather than a
merge. If upstream ever *must* be patched, record the patch here.

Not an `EditorPlugin` — there is no `plugin.cfg` and nothing to enable in Project Settings. It is
a plain library folder; the `class_name` declarations (`Card3D`, `CardCollection3D`,
`DragController`, `CardLayout` and its three strategies, `DragStrategy`) register themselves the
same way every other `class_name` in this project does.

## Two things that bite

**Instantiate the scenes, never the classes.** `CardCollection3D`'s `@export` setters reach into
`$DropZone/CollisionShape3D`, which only exists in `card_collection_3d.tscn`. A bare
`CardCollection3D.new()` has no such child and the setter fails. Same for `Card3D` — its input
path is a `StaticBody3D` sibling that only the scene provides.

**Input needs physics picking.** `Card3D` receives mouse input through
`StaticBody3D.input_event`, which does nothing unless `get_viewport().physics_object_picking` is
`true`. It defaults to `false`. Godot also resolves Control GUI input *before* physics picking, so
any `Control` with `mouse_filter != IGNORE` covering the table makes every card inert.
