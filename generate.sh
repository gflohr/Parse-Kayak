#! /bin/sh

YAPP=${YAPP:-yapp}

mkdir -p lib/Parse/Kalex
$YAPP -v -m Parse::Kalex::Parser -s -o lib/Parse/Kalex/Parser.pm kalex.y
