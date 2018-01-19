#! /bin/sh

YAPP=${YAPP:-yapp}

mkdir -p lib/Parse/Kalex
$YAPP -v -m Parse::Kalex::Parser -o lib/Parse/Kalex/Parser.pm kalex.y
