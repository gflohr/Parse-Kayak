# Parse-Kayak

Kayak is a compiler compiler for Perl.  It includes both a lexer (`kalex`) and
parser generator (`kayak`) designed to work together.

## Description

The suite of programs in this module can be thought of as the Perl equivalent
of GNU bison resp. yacc and Flex resp. lex but for Perl.  Both programs are
designed to work together.

The lexical scanner `kalex` is documented at 
[lib/Parse/Kalex.md](lib/Parse/Kalex.md), the compiler compiler `kayak`
will be documented at [lib/Parse/Kalex.md](lib/Parse/Kalex.md).

## Status

Pre-alpha, work in progress.

## Copryight

Copyright (C) 2018, Guido Flohr, <guido.flohr@cantanea.com>,
all rights reserved.
