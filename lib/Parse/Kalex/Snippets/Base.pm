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

use Scalar::Util qw(blessed reftype);

sub new {
    my ($class, %options) = @_;

    my $self = bless {
        yyin => \*STDIN,
        yyinname => '<stdin>',
        yyout => \*STDOUT,
        yyoutname => '<stdout>',
        __yypattern_cache => [],
        __yystate => [0],
    }, $class;

    # This will inject the following members:
    #
    # - __rules
    # - __condition_types
    # - __condition_names
    $self->__yyinit;
}

sub __yygetlines {
    my ($self) = @_;

    my $yyin = $self->{yyin};
    if (ref $yyin) {
        if ('GLOB' eq reftype $yyin || blessed $yyin) {
            return $yyin->getlines;
        } elsif ('SCALAR' eq reftype $yyin) {
            return $$yyin;
        }
    }

    # Filename.
    open my $fh, '<', $yyin
        or die "$yyin: $!\n";

    $self->{yyin} = $fh;
    $self->{yyinname} = $yyin;

    return $fh->getlines;    
}

sub yyprint {
    my ($self, $data) = @_;

    my $yyout = $self->{yyout};
    if (ref $yyout) {
        if ('GLOB' eq reftype $yyout || blessed $yyout) {
            return $yyout->print($data);
        } elsif ('SCALAR' eq reftype $yyout) {
            open my $fh, '>', $yyout;
            $yyout = $fh;
            $self->{yyoutname} = '<scalar>';
            $yyout->print($data);
        }
    }

    # Filename.
    open my $fh, '>', $yyout
        or die "$yyout: $!\n";

    $self->{yyout} = $fh;
    $self->{yyoutname} = $yyout;

    return $fh->print($data);
}

sub ECHO {
    my ($self) = @_;

    return $self->yyprint($^N);
}

sub YYPUSH {
    my ($self, $state) = @_;

    $self->__yyvalidateStartCondition($state);
    push @{$self->{__yystate}}, $state;

    return $self;
}

sub YYPOP {
    my ($self) = @_;

    pop @{$self->{__yystate}}
        or die "POP called but start condition stack is empty!\n";

    return $self;
}

sub YYBEGIN {
    my ($self, $state) = @_;

    $self->__yyvalidateStartCondition($state);
    $self->{__yystate} = [$state];

    return $self;
}

sub __yyvalidateStartCondition {
    my ($self, $state) = @_;

    if (!defined $state || !length $state) {
        die "YYPUSH/YYPOP/YYBEGIN called with empty start condition\n";
    }

    return 0 if 0 == $state;
    
    if (!exists $self->{__yycondition_names}->{$state}) {
        die "YYPUSH/YYPOP/YYBEGIN called with undeclared start"
            . " condition'$state'.\n";
    }

    return $self->{__yycondition_names}->{$state};
}

sub __yywrap {
    my ($self) = @_;

    if (!exists $self->{__yyinput}) {
        # First round.
        $self->{__yyinput} = join '', $self->__yygetlines;
    }

    while (!length $self->{__yyinput}) {
        if ($self->{__yyoptions}->{yywrap}) {
            return $self if $self->yywrap;
        } else {
            return $self;
        }

        $self->{__yyinput} = join '', $self->__yygetlines;
    }

    return;
}

sub __yypattern {
    my ($self) = @_;

    # FIXME! Check if a rule was rejected and generate a new pattern!

    my $state = $self->{__yystate}->[-1];

    return $self->{__yypatterns}->[$state];
}

sub __yyinitMatcher {
    my ($self) = @_;

    # The indices into this array are condition numbers, the items
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

    $self->{__yypatterns} = \@patterns;

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

        my $pattern = '(' . $self->__yyfixupRegex($rule, $parentheses) . ')';
        
        $pattern .= "(?{\$self->{__yymatch} = [$r, $parentheses, $rule->[2]]})";
        push @patterns, $pattern;

        $self->{__yypattern_cache}->[$r]->[$parentheses] = $pattern;

        $parentheses += $rule->[2];
    }

    my $re = join '|', @patterns;

    use re qw(eval);

    # FIXME! Case-insensitive matches?
    return qr/^$re/o;
}

sub __yyfixupRegex {
    my ($self, $rule, $parentheses) = @_;

    my $pattern = $rule->[1];
    my $fixes = $rule->[3];
    my $offset = 0;
    foreach my $spec (@$fixes) {
        my ($type, $position, $length, $id) = @$spec;
        my $fixed;
        
        if ('b' eq $type) {
            $fixed = '\\' . ($id + $parentheses);
        } elsif ('v' eq $type && exists $self->{__yyvariables}->{$id}) {
            $fixed .= ${$self->{__yyvariables}->{$id}};
        } else {
            next;
        }

        substr $pattern, $position + $offset, $length, $fixed;

        $offset += (length $fixed) - $length;
    }

    return $pattern;
}

1;
