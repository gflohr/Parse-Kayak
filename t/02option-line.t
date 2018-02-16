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

sub check_line($);

my ($lexer_file, $has_line);
$lexer_file = create_lexer 'echo', x_no_require => 1;
$has_line = check_line $lexer_file;
ok $has_line, 'default';
ok unlink $lexer_file;

$lexer_file = create_lexer 'echo', x_no_require => 1, line => 0;
$has_line = check_line $lexer_file;
ok !$has_line, 'command-line noline';
ok unlink $lexer_file;

$lexer_file = create_lexer 'option-line', x_no_require => 1, line => 0;
$has_line = check_line $lexer_file;
ok !$has_line, 'command-line noline overrides option';
ok unlink $lexer_file;

$lexer_file = create_lexer 'option-noline', x_no_require => 1, line => 0;
$has_line = check_line $lexer_file;
ok !$has_line, 'command-line noline matches nooption';
ok unlink $lexer_file;

$lexer_file = create_lexer 'option-line', x_no_require => 1, line => 1;
$has_line = check_line $lexer_file;
ok $has_line, 'command-line line matches option';
ok unlink $lexer_file;

$lexer_file = create_lexer 'option-noline', x_no_require => 1, line => 1;
$has_line = check_line $lexer_file;
ok $has_line, 'command-line line overrides option';
ok unlink $lexer_file;

$lexer_file = create_lexer 'option-line', x_no_require => 1;
$has_line = check_line $lexer_file;
ok $has_line, 'option only';
ok unlink $lexer_file;

$lexer_file = create_lexer 'option-noline', x_no_require => 1;
$has_line = check_line $lexer_file;
ok !$has_line, 'nooption only';
ok unlink $lexer_file;

done_testing;

sub check_line($) {
    my ($lexer_file) = @_;

    open my $fh, "<$lexer_file";
    while (<$fh>) {
        return 1 if /^#line /;
    }

    return;
}
