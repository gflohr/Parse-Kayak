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

my $lexer = create_lexer 'YYshrink';
$lexer->{yyin} = 't/scanners/YYshrink.in';
assert_location $lexer, initial => 1, 0, 1, 0;
is $lexer->yylex, 1, 'yylex #1';
is $lexer->{yytext}, "Gallia";
assert_location $lexer, Gallia => 1, 1, 1, 6; 
is $lexer->yylex, 2, 'yylex #2';
is $lexer->{yytext}, "omnis";
assert_location $lexer, omnis => 1, 12, 1, 16;
is $lexer->yylex, 3, 'yylex #3';
is $lexer->{yytext}, "Belgae";
assert_location $lexer, Belgae => 1, 62, 1, 67;
is $lexer->yylex, 4, 'yylex #4';
is $lexer->{yytext}, "Aquitani";
assert_location $lexer, Aquitani => 2, 7, 2, 14;

done_testing;
