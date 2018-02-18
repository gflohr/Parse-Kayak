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
use Storable qw(freeze);

sub new {
    my ($class) = @_;

    my $self = bless {
        yyin => \*STDIN,
        yyinname => '<stdin>',
        yyout => \*STDOUT,
        yyoutname => '<stdout>',
        __yystate => [0],
        yy_kalex_debug => 1,
    }, $class;

    # This will inject the following members:
    #
    # - __rules
    # - __condition_types
    # - __condition_names
    $self->__yyinit;

    if ($self->{__yyoptions}->{yylineno}) {
        $self->{__yylocation} = [1, 0, 1, 0];
        $self->{__yylastlocation} = [1, 0];
        $self->{__yyunread} = 0;
    }

    return $self;
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

    return $self->yyprint($self->{yytext});
}

sub YYPUSH {
    my ($self, $state) = @_;

    my $nstate = $self->__yyvalidateStartCondition($state);
    push @{$self->{__yystate}}, $nstate;

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

    my $nstate = $self->__yyvalidateStartCondition($state);
    $self->{__yystate} = [$nstate];

    return $self;
}

sub REJECT {
    my ($self) = @_;

    my $ruleno = $self->{__yymatch}->[0];

    $self->{__yyrejected}->{$ruleno} = 1;
    $self->{__yyreject_valid} = 1;
    $self->{yypos} -= length $self->{__yytext};

    if ($self->{__yyoptions}->{yylineno}) {
        my $lastloc = $self->{__yylastlocation};
        my $loc = $self->{__yylocation};
        # Rewind last location for next match.
        if ($self->{__yyvalidlocation}) {
            $lastloc->[0] = $loc->[0];
            $lastloc->[1] = $loc->[1] - 1;
            $self->{__yyunread} += length $self->{__yytext};
        }
    }

    # FIXME! Do the equivalent for yyless()!
    $self->{yytext} = $self->{__yytext} = '';

    return $self;
}

sub yymore {
    my ($self) = @_;

    $self->{__yymore} = 1;

    return $self;
}

sub yyless {
    my ($self, $pos) = @_;

    my $length = length $self->{__yytext};
    if ($pos < 0) {
        require Carp;
        Carp::croak("yyless() called with negative argument $pos");
    }

    $self->{yypos} -= $length;
    $self->{yytext} = $self->{__yytext}
        = substr $self->{yyinput}, $self->{yypos}, $pos;
    $self->{yypos} += $pos;

    if ($self->{__yyoptions}->{yylineno}) {
        # We have to move the old location so that it points to the character
        # in front of the current match.
        if ($self->{__yyvalidlocation}) {
            my @location = @{$self->{__yylocation}};
            my @last = @{$self->{__yylastlocation}};
            $last[0] = $location[0];
            $last[1] = $location[1] - 1;
            $self->{__yylastlocation} = \@last;

            $self->{__yyunread} = $pos - $self->{yypos} 
                                  + length $self->{yyinput};
        }
        
        my $new_match = substr $self->{yyinput}, $self->{yypos} - $pos, $pos;
        $self->__yyupdateLocation($new_match);
    }

    return $self;
}

sub yyrecompile {
    my ($self) = @_;

    local $Storable::canonical = 1;
    $self->{__yycanonical} = freeze $self->{__yyvariables};

    $self->__yycompileActivePatterns;

    return $self;
}

sub yyunput {
    my ($self, $what) = @_;

    substr $self->{yyinput}, $self->{yypos}, 0,  $what;

    return $self;
}

sub yyinput {
    my ($self, $num) = @_;

    $num = 1 if !defined $num;
    return '' if $num <= 0;

    my $skipped = substr $self->{yyinput}, $self->{yypos}, $num;

    $self->{yypos} += $num;

    if ($self->{__yyvalidlocation}) {
        # Move start of next match forward.
        $self->{__yyunread} -= $num;

        my $lastloc = $self->{__yylastlocation};
        my $newlines = $skipped =~ y/\n/\n/;
        if ($newlines) {
            $lastloc->[0] += $newlines;
            my $rindex = rindex $skipped, "\n";
            $lastloc->[1] = -1 - $rindex + $num;
        } else {
            $lastloc->[1] += $num;
        }
    }

    return $skipped;
}

sub yylocation {
    my ($self) = @_;

    return wantarray ? @{$self->{__yylocation}} : $self->{__yylocation}->[0];
}

sub yyrestart {
    my ($self, $yyin) = @_;

    $self->{$yyin} = $yyin;
    $self->{yyinput} = '';
    $self->{yypos} = 0;

    return $self;
}

sub yyrewind {
    my ($self, $num) = @_;

    if ($num < 0) {
        require Carp;
        Carp::croak("yyrewind() called with negative argument $num");
    }

    $self->{yypos} -= $num;
    $self->{yypos} = 0 if $self->{yypos} < 0;

    if ($self->{__yyvalidlocation}) {
        $self->{__yyunread} += $num;

        my $lastloc = $self->{__yylastlocation};
        my $rewind = substr $self->{yyinput}, $self->{yypos}, $num;
        my $newlines = $rewind =~ y/\n/\n/;
        if ($newlines) {
            $lastloc->[0] -= $newlines;
            my $parsed = substr $self->{yyinput}, 0, $self->{yypos};
            my $rindex = rindex $parsed, "\n";
            if ($rindex == -1) {
                # FIXME! Must be tested!
                $lastloc->[1] = $self->{yypos};
            } else {
                $lastloc->[1] = $self->{yypos} - $rindex - 1;
            }
        } else {
            $lastloc->[1] -= $num;
        }
    }

    return $self;
}

sub __yyescape {
    my ($self, $string) = @_;

    my %escapes = (
        "\007" => 'a',
        "\010" => 'b',
        "\011" => 't',
        "\012" => 'n',
        #"\013" => 'v',
        "\014" => 'f',
        "\015" => 'r',
        "\033" => 'e',
        '"' => '"',
        '\\' => '\\',
    );

    $string =~ s{([\000-\037\\"])}{
        if (exists $escapes{$1}) {
            '\\' . $escapes{$1};
        } else {
            sprintf '\\%03o', ord $1;
        }
    }ge;

    return $string;
}

# Updating the location is pretty convoluted in the presence of the functions
# REJECT, yymore(), and yyinput().  Finally, yyunput() can make accurate
# location tracking completely impossible, because inserts user-supplied
# strings in the input.
#
# We therefore store the number of characters not yet matched in the
# instance variable__yyunread.
#
# Normally, __yyunread is the difference between the length of yyinput and
# yypos.  REJECT, yymore(), yyless(), and yyinput() correct it accordingly.
# Only yyunput(), which inserts chharacters does *not* update it so that 
# we can see that we are currently matching user-supplied input, at least
# partially.  During that time, the location does not get updated so that it
# still points to where it was before the call to yyunput().
sub __yyupdateLocation {
    my ($self, $match) = @_;

    my $lyyinput = length $self->{yyinput};
    my $lmatch = length $match;
    my @loc;
    # It is too optimistic to assume that the "normal" case will
    # always be exactly true.  If we lost track because of wild mixing of
    # REJECT, yymore, yyless, yyinput, and yyunput, we should make sure
    # that the algorithm is self-healing and will find a valid location
    # after some time.  That's why the second condition is added here.
    # This has to be tested though.
    if ($lyyinput - $self->{yypos} == $self->{__yyunread} - $lmatch
        || $self->{yypos} - $lmatch > $lyyinput - $self->{__yyunread}) {
        # Normal case.
        $self->{__yyunread} = $lyyinput - $self->{yypos};

        if ($self->{__yymore}) {
            # Do not move start of the location.
            $match = $self->{__yytext} . $match;
            $lmatch = length $match;
            @loc = ($self->{__yylocation}->[0], $self->{__yylocation}->[1]);   
        } else {
            # The start of the location is the character after the last
            # location.
            @loc = @{$self->{__yylastlocation}};
            $loc[1]++;
        }
        $self->{__yyvalidlocation} = 1;
    } elsif ($self->{yypos} + $lmatch > $lyyinput - $self->{__yyunread}
             && !$self->{__yymore}) {
        # The first part of the match comes from yyunput().
        # Pretend that the match only consists of the part not inserted with
        # yyunput().  That means that we have to shorten $match and set
        # @loc to the beginning of the current match (the one that we didn't
        # change).
        $loc[0] = $self->{__yylocation}->[2];
        $loc[1] = $self->{__yylocation}->[3] + 1;
        my $fake_pos = $lyyinput - $self->{__yyunread};
        $lmatch = $self->{yypos} - $fake_pos;
        $match = substr $self->{yyinput}, $fake_pos, $lmatch;
        $self->{__yyunread} = $lyyinput - $fake_pos - $lmatch;

        # Still prevent any fancy location stuff because the location that we'll
        # compute this round will only be half true.
        delete $self->{__yyvalidlocation};
    } else {
        # Leave location untouchhed.
        delete $self->{__yyvalidlocation};
        return $self;
    }

    my $newlines = $match =~ y/\n/\n/;
    if ($newlines) {
        $loc[2] = $loc[0] + $newlines;
        my $rindex = rindex $match, "\n";
        if (0 == $rindex && !$self->{__yymore}) {
            $loc[0] = 0;
            ++$loc[1];
        }
        $loc[3] = -1 - $rindex + $lmatch;
    } else {
        $loc[2] = $loc[0];
        $loc[3] = -1 + $loc[1] + $lmatch;
    }

    $self->{__yylocation} = \@loc;
    $self->{__yylastlocation} = [$loc[2], $loc[3]];

    return $self;
}

sub __yymatch {
    my ($self, $match) = @_;

    if ($self->{__yyoptions}->{debug}
        && $self->{yy_kalex_debug}) {
        my $ruleno = $self->{__yymatch}->[0];
        my $default_rule = -1 + @{$self->{__rules}};
        my $pretty_match = $self->__yyescape($match);
        my $condition = $self->{__yyconditions}[$self->{__state}->[-1]];
        if ($ruleno == $default_rule) {
            print STDERR qq{<$condition> accepting default rule ("$pretty_match")\n};
        } else {
            my $rule = $self->{__rules}->[$ruleno];
            my $location = $rule->[4]->[0]
                . " line " . $rule->[4]->[1];
            ++$ruleno;
            print STDERR qq{<$condition> accepting rule #$ruleno at $location ("$pretty_match")\n};
        }
    }

    $self->{yypos} += length $match;

    $self->__yyupdateLocation($match) if $self->{__yyoptions}->{yylineno};

    $self->{__yytext} = $match;

    if (delete $self->{__yymore}) {
        $self->{yytext} .= $match;
    } else {
        $self->{yytext} = $match;
    }

    return $self;
}

sub __yyvalidateStartCondition {
    my ($self, $state) = @_;

    if (!defined $state || !length $state) {
        die "YYPUSH/YYPOP/YYBEGIN called with empty start condition\n";
    }

    return 0 if '0' eq $state;
    
    if (!exists $self->{__yycondition_names}->{$state}) {
        die "YYPUSH/YYPOP/YYBEGIN called with undeclared start"
            . " condition'$state'.\n";
    }

    return $self->{__yycondition_names}->{$state};
}

sub __yywrap {
    my ($self) = @_;

    if (!exists $self->{yyinput}) {
        # First round.
        $self->{yyinput} = join '', $self->__yygetlines;
        $self->{yypos} = 0;
        if ($self->{__yyoptions}->{yylineno}) {
            $self->{__yylocation} = [1, 0, 1, 0];
            $self->{__yyunread} = length $self->{yyinput};
        }
    }

    while ($self->{yypos} >= length $self->{yyinput}) {
        if ($self->{__yyoptions}->{yywrap}) {
            return $self if $self->yywrap;
        } else {
            return $self;
        }

        $self->{yyinput} = join '', $self->__yygetlines;
        $self->{yypos} = 0;
        if ($self->{__yyoptions}->{yylineno}) {
            $self->{__yylocation} = [1, 0, 1, 0];
            $self->{__yyunread} = length $self->{yyinput};
        }
    }

    return;
}

sub __yypattern {
    my ($self) = @_;

    # FIXME! Check if a rule was rejected and generate a new pattern!
    my $rejected = '';
    if (delete $self->{__yyreject_valid}) {
        $rejected = join ':',
                    sort { $a <=> $b }
                    keys %{$self->{__yyrejected}};
        $self->__yycompileActivePatterns;
    } else {
        delete $self->{__yyrejected};
    }

    my $state = $self->{__yystate}->[-1];

    return $self->{__yypatterns}->{$self->{__yycanonical}}->{$rejected}->[$state];
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

    $self->{__yyactive} = \@active;

    return $self;
}

sub __yycompileActivePatterns {
    my ($self, $rule) = @_;

    my $canonical = $self->{__yycanonical};
    my $rejected = $self->{__yyrejected} ?
        (join ':', sort { $a <=> $b } keys %{$self->{__yyrejected}}) : '';
    return $self if exists $self->{__yypatterns}->{$canonical}->{$rejected};

    my @patterns;
    foreach my $rules (@{$self->{__yyactive}}) {
        push @patterns, $self->__yycompilePatterns($rules);
    }

    $self->{__yypatterns}->{$canonical}->{$rejected} = \@patterns;

    return $self;
}

sub __yycompilePatterns {
    my ($self, $rules) = @_;

    # Count the number of parentheses so that backreferences can be fixed
    # and @_ will be filled correctly.
    my $parentheses = 0;
    my @patterns;
    my $rejected = $self->{__yyrejected} || {};
    foreach my $r (@$rules) {
        next if $rejected->{$r};

        ++$parentheses;

        my $rule = $self->{__rules}->[$r];
        my $regex = $rule->[1];

        my $pattern = '(' . $self->__yyfixupRegex($rule, $parentheses) . ')';
        
        $pattern .= "(?{\$self->{__yymatch} = [$r, $parentheses, $rule->[2]]})";
        push @patterns, $pattern;

        $parentheses += $rule->[2];
    }

    my $re = join '|', @patterns;

    use re qw(eval);

    return qr/\G$re/m;
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
