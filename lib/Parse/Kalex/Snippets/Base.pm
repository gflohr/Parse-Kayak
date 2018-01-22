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
        __yypattern_cache => [],
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

sub __yyinitMatcher {
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

    my @patterns;
    foreach my $rules (@active) {
        push @patterns, $self->__yycompilePatterns($rules, -1);
    }

    return $self;
}

sub __yycompilePatterns {
    my ($self, $rules, $reject) = @_;

    # Count the number of parentheses so that backreferences can be fixed
    # and @_ will be filled correctly.
    my $parentheses = 0;
    my @patterns;
    foreach my $r (@$rules) {
        next if $r <= $reject;

        ++$parentheses;
        if ($self->{__yypattern_cache}->[$r]->[$parentheses]) {
            push @patterns, $self->{__yypattern_cache}->[$r]->[$parentheses];
            next;
        }

        my $rule = $self->{__rules}->[$r];
        my $regex = $rule->[1];

        my $pattern = $self->__yyfixupBackrefs($rule, $parentheses);
        
        # There are several ways finding out which pattern matched.  You
        # can check the return value of the match and check which elemeents
        # are defined.  When you count all captures, you can find out which
        # rule caused the match.
        #
        # In a similar manner you can use @- and @+ that contain the boundaries
        # of all matches and submatches.
        #
        # The most efficient way is to embed tiny code snippets which give
        # you all the relevant information.  We store that in the variables
        # $yyrule and $__yyoffset.
        $pattern .= "(?{\$yyrule = $r; \$__yyoffset = $parentheses;})";
        push @patterns, "($pattern)";

        $self->{__yypattern_cache}->[$r]->[$parentheses] = $pattern;

        $parentheses += $rule->[2];
    }

    # Add the default match.
    my $default_rule = @{$self->{__rules}};
    ++$parentheses;

    my $pattern = '((?s:.))'
            . "(?{\$yyrule = $default_rule; \$__yyoffset = $parentheses;})";
    push @patterns, $pattern;

    my $re = join '|', @patterns;

    use re qw(eval);

    # FIXME! Case-insensitive matches?
    # FIXME! The variables most probably have to be declared within
    # yylex() and the pattern also have to be compiled there.
    my $yyrule;
    my $__yyoffset;
    return qr/^$re/;
}

sub __yyfixupBackrefs {
    my ($self, $rule, $parentheses) = @_;

    my $pattern = $rule->[1];
    my $backrefs = $rule->[3];
    my $offset = 0;
    foreach my $spec (@$backrefs) {
        my ($position, $length, $index) = @$spec;
        my $fixed = '\\' . ($index + $parentheses);
        substr $pattern, $position + $offset, $length, $fixed;
    }

    return $pattern;
}

1;
