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

my $lexer = create_lexer 'YYLocationLexer';
$lexer->{yyin} = 't/scanners/YYLocationLexer.in';
assert_location $lexer, initial => 1, 0, 1, 0;
is $lexer->yylex, 1, 'yylex #1';
assert_location $lexer, omnis => 1, 12, 1, 16;
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
is $lexer->yylex, 13, 'yylex #13';
assert_location $lexer, humanitate => 5, 43, 5, 52;
is $lexer->yylex, 14, 'yylex #14';
assert_location $lexer, minimeque => 6, 9, 6, 17;
is $lexer->yylex, 15, 'yylex #15';
assert_location $lexer, mercatores => 6, 26, 6, 35;
is $lexer->yylex, 16, 'yylex #16';
assert_location $lexer, catchme => 6, 26, 6, 35;
is $lexer->yylex, 17, 'yylex #17';
assert_location $lexer, commeant => 6, 36, 6, 50;
is $lexer->yylex, 18, 'yylex #18';
assert_location $lexer, atque_ea_quae => 6, 52, 6, 64;
is $lexer->yylex, 19, 'yylex #19';
assert_location $lexer, causa_Helvetii => 8, 62, 9, 15;
is $lexer->yylex, 20, 'yylex #20';
assert_location $lexer, Helvetii_quoque => 8, 68, 9, 6;

done_testing;
