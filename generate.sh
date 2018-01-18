#! /bin/sh

YAPP=${YAPP:-yapp}

$YAPP -v -m Parse::Kalex:Parser -s -o lib/Parse/Kalex/Parser.pm kalex.y
