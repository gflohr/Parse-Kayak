# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

use strict;

use vars qw(@ISA @EXPORT_OK);

use Test::More;
use File::Spec;

use Parse::Kalex;

use lib '.';

@ISA = qw(Exporter);
@EXPORT_OK = qw(create_lexer assert_location);

sub create_lexer {
    my ($name, %options) = @_;

    my $lfile = File::Spec->catfile('t', 'scanners', $name . '.l');
    my $scanner_file = File::Spec->catfile('t', 'scanners', $name . '.pm');
    unlink $scanner_file;

    my $scanner = Parse::Kalex->new({outfile => $scanner_file,
                                     package => $name, %options}, 
                                     $lfile);
    ok $scanner, "$name new";
    ok $scanner->scan, "$name scan";
    ok $scanner->output, "$name output";
    ok -e $scanner_file, "$name -> $scanner_file";

    return $scanner_file if delete $options{x_no_require};

    ok require $scanner_file, "$name -> require $scanner_file";
    ok((unlink $scanner_file), "$name -> unlink $scanner_file");

    my $lexer = $name->new;
    ok $lexer, "$name constructor";

    return $lexer;
}

sub assert_location {
    my ($lexer, $test, @expect) = @_;

    my @location = $lexer->yylocation;
    my $name = ref $lexer;

    is $location[0], $expect[0], "$name $test from_line";
    is $location[1], $expect[1], "$name $test from_column";
    is $location[2], $expect[2], "$name $test to_line";
    is $location[3], $expect[3], "$name $test to_column";
}

