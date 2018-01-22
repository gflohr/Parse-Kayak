#! /bin/false

# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

package Parse::Kalex::Snippets::Base;

use strict;

use Locale::TextDomain qw(kayak);
use Scalar::Util qw(blessed);

sub new {
    my ($class, %options) = @_;

    bless {
        yyin => \*STDIN,
        yyout => \*STDOUT,
    }, $class;
}

sub yylex {
    my ($self) = @_;

    if (!exists $self->{__yyinput} || !length $self->{__yyinput}) {
        if ($self->{yyin}->eof) {
            return if $self->yywrap;
        }

        return if $self->{yyin}->eof;

        $self->{__yyinput} = join '', $self->{yyin}->getlines;
    }

    $self->{yyout}->print($self->{__yyinput});
    $self->{__yyinput} = '';

    return $self->__yylex;
}

1;
