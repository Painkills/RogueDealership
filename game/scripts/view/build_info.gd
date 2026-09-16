class_name BuildInfo extends RefCounted
## What build is actually running, so a deployed screen can be matched back
## to the exact commit that produced it rather than guessed at.
##
## CI overwrites LABEL below (tools/stamp_build_info.gd) right before every
## Web export - see .github/workflows/deploy.yml. A local run that never
## went through that step - the editor, a headless driver, this file left
## untouched - shows "dev build" instead, which is itself informative: it
## means whatever is on screen is NOT what got deployed.
##
## Read at actual startup by run_controller.gd, not baked into run.tscn by
## the builder: a scene file's own property values are frozen the moment
## the builder ran locally and got committed, long before CI ever stamps
## this constant - a static bake here would always show whatever build was
## current when someone last ran the builder, never the real one.
##
## stamp_build_info.gd matches the line below by its EXACT current text and
## refuses to run twice - so this file's own comments must never repeat
## that literal line, or a plain string replace corrupts them too.

const LABEL := "dev build"
