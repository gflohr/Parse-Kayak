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
assert_location $lexer, initial => 1, 1, 1, 1;

done_testing;

sub assert_location {
    my ($lexer, $test, @expect) = @_;

    my @location = $lexer->yylocation;
    my $name = ref $lexer;
     
    is $location[0], $expect[0], "$name $test from_line";
    is $location[1], $expect[1], "$name $test from_column";
    is $location[2], $expect[2], "$name $test toline";
    is $location[3], $expect[3], "$name $test to_column";
}
