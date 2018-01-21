# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

use strict;

use Test::More;

use Parse::Kalex;

my $k = Parse::Kalex->new('t/scanners/echo.l');
ok $k, 'echo new';
ok $k->scan, 'echo scan';
ok $k->output, 'echo output';
ok -e 'lex.yy.pl', 'echo -> lex.yy.pl';
ok unlink 'lex.yy.pl', 'echo unlink lex.yy.pl';

done_testing;
