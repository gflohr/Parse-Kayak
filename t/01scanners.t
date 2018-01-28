# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

use strict;

use Test::More;
use File::Spec;
use Parse::Kalex;

sub test_scanner;

foreach my $scanner (qw(
    echo
)) {
    test_scanner $scanner;
}

done_testing;

sub test_scanner {
    my ($name) = @_;

    my $lfile = File::Spec->catfile('t', 'scanners', $name . '.l');
    my $scanner = Parse::Kalex->new($lfile);
    ok $scanner, "$name new";
    ok $scanner->scan, "$name scan";
    ok $scanner->output, "$name output";
    ok -e 'lex.yy.pl', "$name -> lex.yy.pl";
    ok unlink "lex.yy.pl", "$name unlink lex.yy.pl";

    return 1;
}
