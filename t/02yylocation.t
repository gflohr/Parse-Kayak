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

use TestLib;

sub assert_location;

my $lexer = create_lexer 'YYLocationLexer';
$lexer->{yyin} = 't/scanners/YYLocationLexer.in';
assert_location $lexer, initial => 1, 0, 1, 0;
is $lexer->yylex, 1, 'yylex #1';
assert_location $lexer, est => 1, 8, 1, 10;
is $lexer->yylex, 2, 'yylex #2';
assert_location $lexer, Belgae => 1, 62, 2, 5;
is $lexer->yylex, 3, 'yylex #3';
assert_location $lexer, appellantur => 2, 65, 3, 0;
is $lexer->yylex, 4, 'yylex #4';
assert_location $lexer, legibus => 3, 30, 3, 42;
is $lexer->yylex, 5, 'yylex #5';
assert_location $lexer, Gallos => 3, 58, 3, 59;
is $lexer->yylex, 6, 'yylex #6';
assert_location $lexer, Aquitanis => 3, 68, 3, 71;
is $lexer->yylex, 7, 'yylex #7';
assert_location $lexer, Matrona => 4, 26, 4, 36;
is $lexer->yylex, 8, 'yylex #8';
assert_location $lexer, Sequana => 4, 26, 4, 43;
is $lexer->yylex, 9, 'yylex #9';
assert_location $lexer, fortissimi => 4, 67, 5, 0;
is $lexer->yylex, 10, 'yylex #10';
assert_location $lexer, sunt_Belgae => 4, 67, 5, 11;
is $lexer->yylex, 11, 'yylex #11';
assert_location $lexer, propterea_quod => 5, 14, 5, 27;
is $lexer->yylex, 12, 'yylex #12';
assert_location $lexer, propterea => 5, 14, 5, 22;

done_testing;

sub assert_location {
    my ($lexer, $test, @expect) = @_;

    my @location = $lexer->yylocation;
    my $name = ref $lexer;
     
    is $location[0], $expect[0], "$name $test from_line";
    is $location[1], $expect[1], "$name $test from_column";
    is $location[2], $expect[2], "$name $test to_line";
    is $location[3], $expect[3], "$name $test to_column";
}
