#! /bin/false

# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

package main;

use strict;

my $yylexer = Parse::Kalex::Lexer->new;

tie my $yytext, 'Parse::Kalex::Snippets::main::Tier', 
    $yylexer, 'yytext';
tie my $yyin, 'Parse::Kalex::Snippets::main::Tier',
    $yylexer, 'yyin';
tie my $yyinname, 'Parse::Kalex::Snippets::main::Tier',
    $yylexer, 'yyinname';
tie my $yyout, 'Parse::Kalex::Snippets::main::Tier',
    $yylexer, 'yyout';
tie my $yyoutname, 'Parse::Kalex::Snippets::main::Tier',
    $yylexer, 'yyoutname';
tie my $yyinput, 'Parse::Kalex::Snippets::main::Tier',
    $yylexer, 'yyinput';
tie my $yypos, 'Parse::Kalex::Snippets::main::Tier',
    $yylexer, 'yypos';
tie my $yy_kalex_debug, 'Parse::Kalex::Snippets::main::Tier',
    $yylexer, 'yy_kalex_debug';

sub ECHO {
    $yylexer->ECHO;
}

sub YYBEGIN {
    my ($condition) = @_;

    $yylexer->YYBEGIN($condition);
}

sub YYPUSH {
    my ($condition) = @_;

    $yylexer->YYPUSH($condition);
}

sub YYPOP {
    my ($condition) = @_;

    $yylexer->YYPOP($condition);
}

sub yyprint {
    my ($buffer) = @_;

    $yylexer->yyprint($buffer);
}

sub REJECT {
    $yylexer->REJECT;
}

sub yymore {
    $yylexer->yymore;
}

sub yyless {
    my ($pos) = @_;

    if ($pos < 0) {
        require Carp;
        Carp::croak("yyless() called with negative argument $pos");
    }

    $yylexer->yyless($pos);
}

sub yyrecompile {
    $yylexer->yyrecompile;
}

sub unput {
    my ($what) = @_;

    return $yylexer->yyunput($what);
}

sub yyunput {
    my ($what) = @_;

    return $yylexer->yyunput($what);
}

sub input {
    my ($num) = @_;

    return $yylexer->yyinput($num);
}

sub yyinput {
    my ($num) = @_;

    return $yylexer->yyinput($num);
}

sub yyrestart {
    my ($yyin) = @_;

    return $yylexer->yyrestart($yyin);
}

sub yyrewind {
    my ($num) = @_;

    return $yylexer->yyrewind($num);
}

sub yyshrink {
    my ($num) = @_;

    return $yylexer->yyshrink($num);
}

sub yy_start_name {
    my ($num) = @_;

    return $yylexer->yy_start_name($num);
}

sub yy_start_number {
    my ($name) = @_;

    return $yylexer->yy_start_number($name);
}

package Parse::Kalex::Lexer;

use strict;

sub yywrap {
    main::yywrap();
}

package Parse::Kalex::Snippets::main::Tier;

use strict;

sub TIESCALAR {
    my ($class, $obj, $varname) = @_;

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

1;
