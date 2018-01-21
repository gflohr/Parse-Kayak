#! /bin/false

# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

package main;

my $yylexer = Parse::Kalex::Lexer->new;

my $yytext;
tie $yytext, 'Parse::Kalex::Snippets::main::Tier', $yylexer, 'yytext';

my $yyin = \*STDIN;

package Parse::Kalex::Snippets::main::Tier;

sub TIESCALAR {
    my ($self, $obj, $varname) = @_;

    bless {
        __obj => $obj,
        __varname => $varname,
    }, $class;
}

sub FETCH {
   my ($self) = @_;

   return $self->{__obj}->{$self->{__varname}};
}

sub STORE {
   my ($self, $value) = @_;

   $self->{__obj}->{$self->{__varname}} = $value;
}

package main;

print "yytext: $yytext\n";
$yytext = 'Yanas Möse';
print "yytext: $yytext\n";
$yylexer->{yytext} = 'Guidos Schwanz';
print "yytext: $yytext\n";

1;
