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
use Config;

my $this_perl = $^X;
if ($^O ne 'VMS') {
    $this_perl .= $Config{_exe}
        unless $this_perl =~ /$Config{_exe}$/i;
}

sub test_scanner;
sub compare_files;

my $scannerdir = File::Spec->catfile('t', 'scanners');
opendir my $dh, $scannerdir or die "$scannerdir: $!\n";
my @scanners = map { s/\.expect$//; $_ }
               grep { /\.expect$/ }
               grep { /^[a-zA-Z]/ }
               readdir $dh;

foreach my $scanner (sort @scanners) {
    if (exists $ENV{PARSE_KALEX_FILTERS}) {
        next unless $scanner =~ /^$ENV{PARSE_KALEX_FILTERS}$/;
    }
    test_scanner $scanner;
}

done_testing;

sub test_scanner {
    my ($name) = @_;

    my $lfile = File::Spec->catfile('t', 'scanners', $name . '.l');
    my $expect_file = File::Spec->catfile('t', 'scanners', $name . '.expect');
    my $got_file = File::Spec->catfile('t', 'scanners', $name . '.out');
    my $scanner_file = File::Spec->catfile('t', 'scanners', $name . '.pl');
    my $scanner = Parse::Kalex->new({outfile => $scanner_file}, $lfile);
    ok $scanner, "$name new";
    ok $scanner->scan, "$name scan";
    ok $scanner->output, "$name output";
    ok -e $scanner_file, "$name -> $scanner_file";
    ok 0 == system $this_perl, $scanner_file;
    compare_files $name, $got_file, $expect_file;
    ok unlink $scanner_file, "$name unlink $scanner_file";

    return 1;
}

sub compare_files {
    my ($name, $got_file, $expect_file) = @_;

    open my $fh, '<', $got_file;
    ok $fh, "$name output file exists";
    return if !$fh;
    my $got = join '', <$fh>;

    open my $fh, '<', $expect_file;
    ok $fh, "$name expect file exists";
    return if !$fh;
    my $expect = join '', <$fh>;

    cmp_ok $got, 'eq', $expect, "$name output check";
   
    ok unlink $got_file;

    return 1;
}
