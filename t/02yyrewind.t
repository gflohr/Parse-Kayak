# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

use strict;

use Test::More;

BEGIN {
    my $test_dir = __FILE__;
    $test_dir =~ s/[-a-z0-9]+\.t$//i;
    unshift @INC, $test_dir;
}

use TestLib qw(assert_location create_lexer);

my $lexer = create_lexer 'YYrewind';
$lexer->{yyin} = 't/scanners/YYrewind.in';
assert_location $lexer, initial => 1, 0, 1, 0;
is $lexer->yylex, 1, 'yylex #1';
assert_location $lexer, unam => 1, 48, 2, 5;
is $lexer->yylex, 2, 'yylex #2';
assert_location $lexer, Belgae => 1, 62, 1, 67;

done_testing;
