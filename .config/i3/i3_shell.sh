#!/bin/bash
WHEREAMI=$(cat /tmp/whereami)
if $WHEREAMI == ""; then
    termite
else
    termite --directory="$WHEREAMI"
fi
