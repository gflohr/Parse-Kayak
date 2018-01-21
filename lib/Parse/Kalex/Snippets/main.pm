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

tie my $yytext, 'Parse::Kalex::Snippets::main::Tier', $yylexer, 'yytext';
tie my $yyin, 'Parse::Kalex::Snippets::main::Tier', $yylexer, 'yytext';

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