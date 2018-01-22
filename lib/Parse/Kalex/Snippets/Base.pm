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

    my $self = bless {
        yyin => \*STDIN,
        yyout => \*STDOUT,
    }, $class;

    # This will inject the following members:
    #
    # - __rules
    # - __condition_types
    $self->__yyinit;
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

sub __initMatcher {
    my ($self) = @_;

    # This indices into this array are condition numbers, the items
    # are arrays of active rule numbers;
    my @active;
    for (my $r = 0; $r < @{$self->{__rules}}; ++$r) {
        my $conditions = $self->{__rules}->[$r]->[0];
        foreach my $c (@$conditions) {
            if ($c < 0) {
                # <*>: Activate for all start conditions.
                for (my $i = 0; $i < @{$self->{__condition_types}}; ++$i) {
                    $active[$i] ||= [];
                    push @{$active[$i]}, $r;
                }
            } else {
                $active[$c] ||= [];
                push @{$active[$c]}, $r;
            }
        }
        if (!@$conditions) {
            # No start condition.  This rule is active for all inclusive
            # start conditions.
            for (my $c = 0; $c < @{$self->{__condition_types}}; ++$c) {
                if ('s' eq $self->{__condition_types}->[$c]) {
                    $active[$c] ||= [];
                    push @{$active[$c]}, $r;
                }
            }
        }
    }

    return $self;
}

1;
