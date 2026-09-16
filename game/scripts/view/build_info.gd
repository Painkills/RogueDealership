class_name BuildInfo extends RefCounted
## What build is actually running, so a deployed screen can be matched back
## to the exact commit that produced it rather than guessed at.
##
## CI overwrites LABEL below (a single line, easy to sed) right before every
## Web export - see .github/workflows/deploy.yml. A local run that never
## went through that step - the editor, a headless driver, this file left
## untouched - shows "dev build" instead, which is itself informative: it
## means whatever is on screen is NOT what got deployed.

const LABEL := "dev build"
