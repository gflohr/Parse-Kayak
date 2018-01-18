#! /bin/sh

YAPP=${YAPP:-yapp}

$YAPP -v -m Parse::WLex::Parser -s -o lib/Parse/WLex/Parser.pm wlex.y
