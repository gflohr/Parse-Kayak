#! /bin/false

# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

package Parse::Kalex::Generator;

use strict;

use Locale::TextDomain qw(kayak);
use Data::Dumper;

sub new {
    my ($class, $lexer) = @_;

    bless {
        __errors => 0,
        __top_code => [],
        __def_code => [],
        __lexer => $lexer,
        __filename => '',
        __start_conditions => {
            INITIAL => 0,
        },
        __xstart_condtions => {},
        __condition_counter => 0,
        __condition_types => ['s'],
        __condition_names => ['INITIAL'],
        __rules => [],
        __options => {},
    }, $class;
}

sub addOptions {
    my ($self, $options) = @_;

    foreach my $pair (@$options) {
        my ($option, $value) = @$pair;
        $self->{__options}->{$option} = $value;
    }

    return $self;
}

sub checkOption {
    my ($self, $option, $value) = @_;

    my %options = (
        yywrap => 1,
    );
    my %voptions = (
    );

    if (exists $options{$option}) {
        if (3 == @_) {
            my $location = $self->{__lexer}->yylocation;
            warn __x("{location}: error: option '{option}' does"
                     . " not take an argument.\n",
                     location => $location, option => $option);
            ++$self->{__errors};
        }
        return [$option, 1];
    }

    if (exists $voptions{$option}) {
        if (3 != @_) {
            my $location = $self->{__lexer}->yylocation;
            warn __x("{location}: error: option '{option}'"
                     . " requires an argument.\n",
                     location => $location, option => $option);
            ++$self->{__errors};
        }
        return [$option, $value];
    }

    if ($option =~ /^(no)(.*)/ && exists $options{$2}) {
        if (3 == @_) {
            my $location = $self->{__lexer}->yylocation;
            warn __x("{location}: error: option '{option}' does"
                     . " not take an argument.\n",
                     location => $location, option => $option);
            ++$self->{__errors};
        }
        $option = $2;
        return [$option, 0];
    }

    my $location = $self->{__lexer}->yylocation;
    warn __x("{location}: error: option '{option}' does"
             . " not take an argument.\n",
             location => $location, option => $option);
    ++$self->{__errors};

    return [$option, $value];
}

sub addTopCode {
    my ($self, $code) = @_;

    my @location = $self->{__lexer}->yylocation;
    push @{$self->{__top_code}}, [ $code, @location ];

    return $self;
}

sub addDefCode {
    my ($self, $code) = @_;

    my @location = $self->{__lexer}->yylocation;
    push @{$self->{__def_code}}, [ $code, @location ];

    return $self;
}

sub setUserCode {
    my ($self, $code) = @_;

    my @location = $self->{__lexer}->yylocation;
    $self->{__user_code} = [$code, @location ];

    return $self;
}

sub addStartConditions {
    my ($self, $type, $conditions) = @_;

    if ($type eq '%x') {
        foreach my $condition (@$conditions) {
            $self->{__xstart_conditions}->{$condition} 
                = ++$self->{__condition_counter};
            push @{$self->{__condition_types}}, 'x';
            push @{$self->{__condition_names}}, $condition;
        }
    } else {
        foreach my $condition (@$conditions) {
            $self->{__start_conditions}->{$condition}
                = ++$self->{__condition_counter};
            push @{$self->{__condition_types}}, 's';                
            push @{$self->{__condition_names}}, $condition;
        }
    }

    return $self;
}

sub checkStartConditionDeclaration {
    my ($self, $condition, $exclusive) = @_;

    if (exists $self->{__start_conditions}->{$condition}
        || exists $self->{__xstart_conditions}->{$condition}) {
        my $location = $self->{__lexer}->yylocation;
        warn __x("{location}: warning: start condition '{condition}'"
                 . " is already declared.\n",
                 location => $location, condition => $condition);
    }

    return $self;
}

sub checkStartCondition {
    my ($self, $condition) = @_;

    if (!exists $self->{__start_conditions}->{$condition}
        && !exists $self->{__xstart_conditions}->{$condition}) {
        my $location = $self->{__lexer}->yylocation;
        warn __x("{location}: warning: undeclared start condition '{condition}'.\n",
                 location => $location, condition => $condition);
        $self->{__start_conditions}->{$condition}
            = ++$self->{__condition_counter};
        push @{$self->{__condition_types}}, 's';
        push @{$self->{__condition_names}}, $condition;
    }

    return $self;
}

sub addRule {
    my ($self, $start_conditions, $regex, $code,
        $filename, $lineno, $charno) = @_;

    # Translate the start conditions into numbers.
    my @start_conditions;
    foreach my $condition (@$start_conditions) {
        if ('*' eq $condition) {
            push @start_conditions, '-1';
        } elsif (exists $self->{__start_conditions}->{$condition}) {
            push @start_conditions, $self->{__start_conditions}->{$condition};
        } else {
            push @start_conditions, $self->{__xstart_conditions}->{$condition};
        }
    }
    push @{$self->{__rules}}, [
        [@start_conditions],
        $regex,
        $code,
        [$filename, $lineno, $charno]];

    return $self;
}

sub addRegex {
    my ($self, $chunk) = @_;

    return Parse::Kalex::Generator::Regex->new(
        $chunk, $self->{__lexer}->yylocation);
}

sub growRegex {
    my ($self, $regex, $chunk) = @_;

    return $regex->grow($chunk);
}

sub errors {
    my ($self) = @_;

    return if !$self->{__errors};

    return $self->{__errors};
}

sub generate {
    my ($self) = @_;

    my $options = $self->{__options};

    my $output = '';
    my $top_code = $self->__topCode;

    if (defined $options->{package}) {
        $output .= <<EOF;
#! /bin/false

# A lexical scanner generated by kalex.

${top_code}package $options->{package};

EOF
    } else {
        $output .= <<EOF;
#! /usr/bin/env perl

# A lexical scanner generated by kalex.

${top_code}
EOF

        $output .= $self->__readModuleCode('Parse/Kalex/Snippets/main.pm');
        $output .= "\npackage main;\n\n";
    }

    $output .= $self->__defCode;

    if (!defined $options->{package}) {
        $output .= "\npackage Parse::Kalex::Lexer;\n"
    }

    $output .= $self->__readModuleCode('Parse/Kalex/Snippets/Base.pm');
    $output .= $self->__writeInit(2 + $output =~ y/\n/\n/);
    $output .= $self->__writeYYLex(2 + $output =~ y/\n/\n/);
    $self->{__filename} = ''; # Invalidate cursor.

    if (!defined $options->{package}) {
        $output .= "package main;\n\nno strict;\n\n";
    }

    $output .= $self->__userCode;

    if (defined $options->{package}) {
        $output .= "\n1;\n";    
    }

    return $output;
}

sub __dumpVariable {
    my ($self, $variable) = @_;

    my $dumper = Data::Dumper->new([$variable]);
    $dumper->Indent(0);
    my $dump = substr $dumper->Dump, 8;
    chop $dump;

    return $dump;
}

sub __writeInit {
    my ($self, $offset) = @_;

    my $filename = $self->{__lexer}->outputFilename;
    my $output = qq{#line $offset "$filename"\n};

    $output .= <<'EOF';
sub __yyinit {
    my ($self) = @_;

    $self->{__rules} = [
EOF
    
    foreach my $rule (@{$self->{__rules}}) {
        # We need the start conditions, the pattern, the number of
        # parentheses and the list of back references.
        my $record = [$rule->[0], $rule->[1]->[0], $rule->[1]->[1], 
                      $rule->[1]->[2]];
        my $dump = $self->__dumpVariable($record);
        $output .= "        $dump,\n";
    }

    my $ctypes = $self->__dumpVariable($self->{__condition_types});
    my $options = $self->__dumpVariable($self->{__options});

    $output .= <<EOF;
    ];
    \$self->{__condition_types} = $ctypes;
    \$self->{__yyoptions} = $options;

    \$self->__yyinitMatcher;
}
EOF

    return $output;
}

sub __writeYYLex {
    my ($self, $offset) = @_;

    my $filename = $self->{__lexer}->outputFilename;
    my $output = qq{#line $offset "$filename"\n};

    $output .= <<'EOF';
sub yylex {
    my ($self) = @_;

    while (1) {
        # Difference to flex! We return false, not 0 on EOF.
        $self->__yywrap and return;
        my $pattern = $self->__yypattern;

        my @matches = $self->{__yyinput} =~ /$pattern/;
        my ($ruleno, $capture_offset, $captures) = @{$self->{__yymatch}};

        @_ = ($self, splice @matches, $capture_offset, $captures);

        my $yytext = $self->{__yytext} = $^N;
        substr $self->{__yyinput}, 0, length $^N, '';
        goto "YYRULE$ruleno";
EOF

    my $ruleno = 0;
    foreach my $rule (@{$self->{__rules}}) {
        my (undef, undef, $action, $location) = @$rule;

        $output .= <<EOF;
#line $location->[1] "$location->[0]"
YYRULE$ruleno: $action

        next;

EOF
        ++$ruleno;
    }

    # Default action.
    my ($filename, $lineno) = (__FILE__, __LINE__);

    $output .= <<EOF;
#line $lineno "$filename"
YYRULE$ruleno: \$self->{yyout}->print(\$^N);
    }

    return;
}
EOF

    return $output;
}

sub __topCode {
    my ($self) = @_;

    my $output = '';

    foreach (@{$self->{__top_code}}) {
        my ($snippet, @location) = @$_;

        chomp $snippet;
        $snippet .= "\n";
        $output .= $self->__addLocation($snippet, @location);
        $output .= $snippet;
    }

    return $output;
}

sub __defCode {
    my ($self) = @_;

    my $output = '';

    foreach (@{$self->{__def_code}}) {
        my ($snippet, @location) = @$_;

        chomp $snippet;
        $snippet .= "\n";
        $output .= $self->__addLocation($snippet, @location);
        $output .= $snippet;
    }

    return $output;
}

sub __userCode {
    my ($self) = @_;

    return '' if !defined $self->{__user_code};

    my ($snippet, @location) = @{$self->{__user_code}};
    chomp $snippet;
    $snippet .= "\n";

    my $output = $self->__addLocation($snippet, @location);
    $output .= $snippet;

    return $output;
}

sub __addLocation {
    my ($self, $snippet, $filename, $lineno) = @_;

    my $location = '';
    if ($filename ne $self->{__filename} || $lineno != $self->{__lineno}) {
        $location = qq{#line $lineno "$filename"\n};
    } 
    $self->{__filename} = $filename;
    $self->{__lineno} = $lineno + ($snippet =~ y/\n/\n/);

    return $location;
}

sub __readModuleCode {
    my ($self, $module) = @_;

    my $code = '';
    eval {
        my $filename;
        foreach my $path (@INC) {
            $filename = File::Spec->catfile($path, $module);
            last if -e $filename;
        }
        die __x("cannot locate '{module}' in \@INC.  (\@INC contains: {INC}).",
                module => $module, INC => join ' ', @INC)
            if !-e $filename;

        open my $fh, '<', $filename
            or die __x("error opening '{filename}' for"
                       . " reading: {error}!",
                       filename => $filename, error => $!);
        my $discarded = 1;
        while (defined(my $line = $fh->getline)) {
            ++$discarded;
            last if $line =~ /^package/;
        }
        $code .= qq{#line $discarded "$module"\n};

        while (defined(my $line = $fh->getline)) {
            last if $line =~ /^1;/;
            $code .= $line;
        }

        if (!length $code) {
            die __x("could not find any code in module '{module}''",
                    module => $module);
        }
    };
    if ($@) {
        die __x("error reading code from mode '{module}': {err}",
                module => $module, err => $@);
    }

    return $code;
}

package Parse::Kalex::Generator::Regex;

sub new {
    my ($class, $chunk, @location) = @_;

    my $parens = 0;
    ++$parens if '(' eq $chunk;
    my @backrefs;
    my @variables;
    if ($chunk =~ /^\\([1-9][0-9]*)$/) {
        push @backrefs, [0, length $chunk, $1];
    } elsif ($chunk =~ /^\$([_a-zA-Z]+)/) {
        push @variables, [0, length $chunk, $1];
    } elsif ($chunk =~ /^\$\{([_a-zA-Z]+)\}/) {
        push @variables, [0, length $chunk, $1];
    }

    bless [
        $chunk,
        $parens,
        \@backrefs,
        \@location,
        \@variables,
    ], $class;
}

sub pattern { shift->[0] }
sub parentheses { shift->[1] }
sub backrefs { shift->[2] }
sub location { @{shift->[3]} }
sub variables { @{shift->[4]} }

sub grow {
    my ($self, $chunk) = @_;

    if ($chunk =~ /^\\([1-9][0-9]*)$/) {
        my $backrefs = $self->backrefs;
        push @$backrefs, [length $self->[0], length $chunk, $1];
    } elsif ($chunk =~ /^\$([_a-zA-Z]+)/) {
        my $variables = $self->variables;
        push @$variables, [length $self->[0], length $chunk, $1];
    } elsif ($chunk =~ /^\$\{([_a-zA-Z]+)\}/) {
        my $variables = $self->variables;
        push @$variables, [length $self->[0], length $chunk, $1];
    }

    $self->[0] .= $chunk;
    ++$self->[1] if '(' eq $chunk;

    return $self;
}

1;
