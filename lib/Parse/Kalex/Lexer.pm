#! /bin/false

# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

package Parse::Kalex::Lexer;

use strict;

# VERSION

use Locale::TextDomain qw(kayak);
use PPI::Tokenizer;

use base 'Parse::Kalex::LexerBase';

my $WS = '[ \011\013-\015]';

sub new {
    my ($class, @input_files) = @_;

    my $self = $class->SUPER::new();
    $self->{__input_files} = \@input_files;
    if (!@input_files) {
        $self->{yyinname} = __"<standard input>";
    } else {
        $self->yywrap;
    }

    bless $self, $class;
}

sub yywrap {
    my ($self) = @_;

    if (@{$self->{__input_files}}) {
        my $filename = shift @{$self->{__input_files}};
        $self->{yyin} = $self->{yyinname} = $filename;
        return;
    }

    return $self;
}

sub __convertComment {
    my ($self, $comment) = @_;

    # This is not the most beautiful conversion but it preserves
    # the number of lines.
    $comment =~ s{^/\*}{ *};
    $comment =~ s{\*/$}{*};

    $comment =~ s{^[ \t]*\*}{#}gm;
    chomp $comment;

    $comment .= "\n";

    return $comment;
}

sub error {
    my ($self) = @_;

    my $location = $self->location;

    if (defined $self->{yypos}) {
        warn __x("{location}: syntax error near '{token}'.\n",
                 location => $location, token => $self->{yytext});
    } else {
        warn __x("{location}: syntax error at beginning of input.\n",
                 location => $location);
    }

    return $self;
}

sub __fatalParseError {
    my ($self, $message) = @_;

    my $location = $self->location;

    $message =~ s/\s+$//;
    $message = __x("{location}: {error}\n",
                   location => $location, error => $message);

    die $message;
}

sub location {
    my ($self) = @_;

    my @l = ($self->{yyinname}, $self->yylocation);
    return @l if wantarray;

    return "$l[0]:$l[1].$l[2]-$l[3].$l[4]";
}

sub __readPerl {
    my ($self, $yyinput) = @_;

    my $delim;
    if ($yyinput =~ s/^\%\{//) {
        $delim = '%}';
    } elsif ($yyinput =~ s/^\{//) {
        $delim = '}';
    } else {
        $self->__fatalParseError("internal error: cannot determine code delimiter");
    }

    my $tokenizer = PPI::Tokenizer->new(\$yyinput);
    my $code = '';
    my $last_token = '';
    my $nesting = 0;
    my @here_doc;
    for (;;) {
        my $token = $tokenizer->get_token;
        if (!defined $token) {
            die $tokenizer->errstr;
        } elsif (0 == $token) {
            die __x("cannot find delimiter '{delimiter}' anywhere"
                    . " before end of file.\n",
                    delimiter => $delim);
        }

        my $content = $token->content;
      
        if ($token->isa('PPI::Token::Structure')) {
            if ('{' eq $content) {
                ++$nesting;
            } elsif ('}' eq $content) {
                if ('%}' eq $delim && '%' eq $last_token) {
                    chop $code;
                    return $code;
                }
                if ('}' eq $delim && !$nesting) {
                    return $code;
                }
                --$nesting;
            }
        } elsif ($token->isa('PPI::Token::HereDoc')) {
            push @here_doc, $token->heredoc, $token->terminator, "\n";
        }

        $code .= $content;
        if (@here_doc && $content =~ /\n/) {
            $code .= join '', @here_doc;
            undef @here_doc;
        }

        $last_token = $content;
    }

    # NOT REACHED.
}

sub __readRuleRegex {
    my ($self, $yyinput) = @_;

    my @location = $self->yylocation;

    # Make PPI::Tokenizer see a pattern match.
    substr $yyinput, 0, 1, 'm';
    my $tokenizer = PPI::Tokenizer->new(\$yyinput);
    my $token = $tokenizer->get_token;

    # Sort the modifiers so that our generated source code will not contain
    # any unsavory words, unless explicitely desired by the author.
    my $modifiers = join '', sort keys %{$token->get_modifiers};
    my $match_string = $token->get_match_string;
    # Move the match pointer forward.  The extra 2 charactersare for the
    # delimiters.
    $self->yyinput(2 + (length $match_string) + (length $modifiers));
    $match_string = "(?$modifiers:" . $match_string . ")";

    my $regex = Parse::Kalex::Generator::Regex->new('', @location);
    
    while ($match_string =~ /
            \G(
            [^\\$(]+                # anything not special
            |
            \(\?                    # non-capturing parentheses.
            |
            \(                      # capturing parentheses
            |
            \\.                     # escaped character
            |
            \$[_a-zA-Z]+            # $variable
            |
            \$\{[_a-zA-Z]+\}        # ${variable}
            |
            .                       # false positive
            )/gsx) {
        $regex->grow($1);
    }

    return $regex;
}

1;
