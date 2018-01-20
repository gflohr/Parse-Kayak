#! /bin/false

# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

# ABSTRACT: LALR parser generator and lexical scanner for Perl

package Parse::Kalex;

use strict;

use Locale::TextDomain qw(kayak);
use Getopt::Long 2.36 qw(GetOptionsFromArray);
use Parse::Kalex::Parser;
use IO::Handle;
use PPI::Tokenizer;

use constant YYEOF => ('', undef);

my $IDENT = '[_a-zA-Z][_a-zA-Z0-9]*';
my $WS = '[ \011\013-\015]';
my $WSNEWLINE = '[ \011-\015]';

sub new {
    my ($class, $options, @input_files) = @_;

    @input_files = ('') if !@input_files;
    my $self = {
        __yyoptions => {%$options},
        yyinput_files => \@input_files,
    };

    bless $self, $class;
}

sub newFromArgv {
    my ($class, $argv) = @_;

    my $self;
    if (ref $class) {
        $self = $class;
    } else {
        $self = bless {}, $class;
    }

    my %options = eval { $self->__getOptions($argv) };
    if ($@) {
        $self->__usageError($@);
    }

    $self->__displayUsage if $options{help};

    if ($options{version}) {
        print $self->__displayVersion;
        exit 0;
    }

    return $class->new(\%options, @$argv);
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
        or $self->__yyfatal(__"POP called but start condition stack is empty!\n");

    return $self;
}

sub YYBEGIN {
    my ($self, $state) = @_;

    $self->__yyvalidateStartCondition($state);
    $self->{__yystate} = [$state];

    return $self;
}

# We do not keep track of the current location.  Instead we calculate it
# only on demand by looking at the current token and the input that has not
# yet been consumed.  Under normal circumstances, this is a lot more efficient
# than constantly tracking the cursor inside the input streams.
sub yylocation {
    my ($self) = @_;

    my $rem = "$self->{__yytext}$self->{__yyinput}";
    my $rem_length = length $rem;

    my $location;
    foreach my $record (reverse @{$self->{__yylocations}}) {
        my ($filename, $length, $lengths) = @$record;
        if ($rem_length > $length) {
            $rem_length -= $length;
        } else {
            $location = $record;
            last;
        }
    }

    die "should not happen" if !$location;

    my ($filename, undef, $lengths) = @$location;
    my $lineno = @$lengths;
    my $charno = 1;
    foreach my $length (reverse @$lengths) {
        if ($rem_length > $length) {
            --$lineno;
            $rem_length -= $length;
        } else {
            $charno = 1 + $length - $rem_length;
            last;
        }
    }

    return wantarray ? ($filename, $lineno, $charno)
                     : join ':', $filename, $lineno, $charno;
}

sub __yyvalidateStartCondition {
    my ($self, $state) = @_;

    if (!defined $state || !length $state) {
        $self->__yyfatal(__x("undefined start condition",
                             condition => $state));        
    }

    my $method = '__yylex' . $state;
    if (!$self->can($method)) {
        $self->__yyfatal(__x("unknown start condition '{condition}'",
                             condition => $state));
    }

    return $method;
}

sub __yyconsumeWhitespace {
    my ($self, $allow_newline) = @_;

    if ($allow_newline) {
        $self->{__yyinput} =~ s/^($WS+)//o;
    } else {
        $self->{__yyinput} =~ s/^($WSNEWLINE+)//o;
    }

    return $1;
}

sub __yynextChar {
    my ($self) = @_;

    if ($self->{__yyinput} =~ s/^(.)//o) {
        return $1, $1;
    }

    return YYEOF;
}

sub __yylexCONDITION_DECLS {
    my ($self) = @_;

    if ($self->{__yyinput} =~ s/^($WS+)//o) {
        return WS => $1;
    } elsif ($self->{__yyinput} =~ s/^(${IDENT})//o) {
        return IDENT => $1;
    } elsif ($self->{__yyinput} =~ s/^\*//o) {
        return '*', '*',
    } elsif ($self->{__yyinput} =~ s/^,//o) {
        return ',', ',';
    } elsif ($self->{__yyinput} =~ s/^>//o) {
        return '>', '>';
    } elsif ($self->{__yyinput} =~ s/^\n//o) {
        $self->YYPOP;
        return NEWLINE => "\n";
    }

    return $self->__yynextChar;
}

sub __yylexFIRST_CONDITION_DECLS {
    my ($self) = @_;

    $self->__yyconsumeWhitespace;

    if ($self->{__yyinput} =~ s/^(${IDENT})//o) {
        $self->YYPOP;
        $self->YYPUSH('CONDITION_DECLS');
        return IDENT => $1;
    } elsif ($self->{__yyinput} =~ s/^\*//o) {
        $self->YYPOP;
        $self->YYPUSH('CONDITION_DECLS');
        return '*', '*',
    } elsif ($self->{__yyinput} =~ s/^,//o) {
        $self->YYPOP;
        $self->YYPUSH('CONDITION_DECLS');
        return ',', ',';
    } elsif ($self->{__yyinput} =~ s/^>//o) {
        $self->YYPOP;
        $self->YYPUSH('CONDITION_DECLS');
        return '>', '>';
    } elsif ($self->{__yyinput} =~ s/^\n//o) {
        $self->YYPOP;
        return NEWLINE => "\n";
    }

    return $self->__yynextChar;
}

sub __yylexCONDITIONS {
    my ($self) = @_;

    $self->__yyconsumeWhitespace;

    if ($self->{__yyinput} =~ s/^(${IDENT})//o) {
        return IDENT => $1;
    } elsif ($self->{__yyinput} =~ s/^\*//o) {
        return '*', '*',
    } elsif ($self->{__yyinput} =~ s/^,//o) {
        return ',', ',';
    } elsif ($self->{__yyinput} =~ s/^>//o) {
        $self->YYPOP;
        return '>', '>';
    }

    return $self->__yynextChar;
}

sub __yylexACTION {
    my ($self) = @_;

    $self->__yyconsumeWhitespace;

    if ($self->{__yyinput} =~ s/^\n//o) {
        # No action.
        $self->YYPOP();
        return ACTION => '';
    } elsif ($self->{__yyinput} =~ /^\{/o) {
        # { ... }
        my $code = $self->__yyReadPerl(\$self->{__yyinput});
        $self->YYPOP();
        return ACTION => $code;
    } elsif ($self->{__yyinput} =~ /^\%\{/o) {
        # %{ ... %}
        my $code = $self->__yyReadPerl(\$self->{__yyinput});
        $self->YYPOP();
        return ACTION => $code;
    } elsif ($self->{__yyinput} =~ s/(.+)\n//o) {
        # One-liner.
        $self->YYPOP();
        return ACTION => $1;
    }

    return $self->__yynextChar;
}

sub __yylexREGEXCC {
    my ($self) = @_;

    if ($self->{__yyinput} =~ s/^(\\.)//o) {
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^(\])//o) {
        $self->YYPOP();
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^\n//o) {
        return NEWLINE => "\n";
    } elsif ($self->{__yyinput} =~ s/^(.)//o) {
        return PATTERN => $1;
    }

    # Cannot happen.
    return YYEOF;
}

sub __yylexREGEX {
    my ($self) = @_;

    if ($self->{__yyinput} =~ /^$WS+/o) {
        $self->YYPOP();
        $self->YYPUSH('ACTION');
        return PATTERN => '';
    } elsif ($self->{__yyinput} =~ s/^(\\.)//o) {
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^(\[\]?)//o) {
        # Character class.  Character classes cannot be empty.  That means
        # that a closing bracket does not have to be escaped if it is the
        # first character.
        $self->YYPUSH('REGEXCC');
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^(\(\??)//o) {
        if (length $1 == 1) {
            # Count captures!  There is no need to treat closing parentheses
            # special.  If they are missing, Perl's regex compiler will
            # complain.
        }
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^\n//o) {
        return NEWLINE => "\n";
    } elsif ($self->{__yyinput} =~ s/^(.)//o) {
        return PATTERN => $1;
    }

    # Cannot happen.
    return YYEOF;
}

sub __yylexRULES {
    my ($self) = @_;

    my ($whitespace) = $self->__yyconsumeWhitespace(1);
    if (defined $whitespace) {
        # FIXME! This is code!
    }

    if ($self->{__yyinput} =~ s/^<//o) {
        $self->YYPUSH('CONDITIONS');
        return '<', '<';
    } elsif ($self->{__yyinput} =~ s/^%%$WS*\n?//o) {
        $self->YYPOP;
        #$self->YYPUSH('USER_CODE');
        return SEPARATOR => '%%';
    } else {
        $self->YYPUSH('REGEX');
        return $self->__yylexREGEX;
    }

    return $self->__yynextChar;
}

sub __yylexINITIAL {
    my ($self) = @_;

    if ($self->{__yyinput} =~ s/^%%$WS*\n?//o) {
        $self->YYPUSH('RULES');
        return SEPARATOR => '%%';
    } elsif ($self->{__yyinput} =~ s/^(%[sx])//o) {
        $self->YYPUSH('FIRST_CONDITION_DECLS');
        return SC => $1;
    }

    return $self->__yynextChar;
}

sub __yylex {
    my ($self) = @_;

    if (!exists $self->{__yyinput}) {
        my $encoding = $self->{__yyoptions}->{encoding};
        binmode STDOUT, ":encoding($encoding)";
        binmode STDERR, ":encoding($encoding)";

        my @filenames = @{$self->{__yyinput_files}};
        my @locations;
        my $input = '';

        if (!@filenames) {
            @filenames = (__"<standard input>");
            binmode STDIN, ":encoding($encoding)";
            my @lengths;
            while (defined (my $line = <STDIN>)) {
                $input .= $line;
                push @lengths, length $line;
            }
            push @lengths, 0 if $input =~ /\n$/;
            push @locations, [__"<standard input>", length $input, \@lengths];
        } else {
            foreach my $filename (@filenames) {
                open my $fh, "<:encoding($encoding)", $filename
                or $self->__yyfatal(__x("error opening '{filename}' for"
                                        . " reading: {error}!",
                                        filename => $filename, error => $!));
                my @lengths;
                my $chunk = '';
                while (defined(my $line = $fh->getline)) {
                    $chunk .= $line;
                    push @lengths, length $line;
                }
                push @lengths, 0 if $chunk =~ /\n$/;
                push @locations, [$filename, length $chunk, \@lengths];
                $input .= $chunk;
            }
        }

        $self->{__yyinput} = $input;
        $self->{__yylocations} = \@locations;

        $self->{__yystate} = ['INITIAL'];
    }

    my $method = $self->__yyvalidateStartCondition($self->{__yystate}->[-1]);
    
    my ($token, $yytext) = $self->$method;

    $self->{yytext} = $self->{__yytext} = $yytext;

    return $token, $yytext;
}

sub __yyerror {
    my ($self) = @_;

    my $location = $self->yylocation;

    if (defined $self->{__yytext}) {
        warn __x("{location}: syntax error near '{token}'.\n",
                 location => $location, token => $self->{__yytext});
    } else {
        warn __x("{location}: syntax error at beginning of input.\n",
                 location => $location, token => $self->{__yytext});
    }

    return $self;
}

sub run {
    my ($self) = @_;

    my $yylex = sub {
        return $self->__yylex;
    };

    my $yyerror = sub {
        return $self->__yyerror;
    };

    my @input_files = @{$self->{yyinput_files}};
    $self->{__yyinput_files} = \@input_files;

    my $parser = Parse::Kalex::Parser->new;
    
    $parser->YYParse(yylex => $yylex,
                     yyerror => $yyerror,
                     yydebug => $ENV{YYDEBUG}) or return;

    return $self;
}

sub output {
    die 'todo';
}

sub programName { $0 }

sub __getOptions {
    my ($self, $argv) = @_;

    my %options = (
        encoding => 'UTF-8'
    );

    Getopt::Long::Configure('bundling');
    GetOptionsFromArray($argv,
        # Scanner behavior
        'e|encoding=s' => \$options{encoding},

        # Informative output.
        'h|help' => \$options{help},
        'V|version' => \$options{version},
    );

    if ($options{encoding} =~ /[\\\)]/) {
        $self->__yyfatal(__x("invalid encoding '{encoding}'!",
                             encoding => $options{encoding}));
    }

    return %options;
}

sub __displayVersion {
    my ($self) = @_;

    my $package = ref $self;

    my $version;
    {
        ## no critic
        no strict 'refs';

        my $varname = "${package}::VERSION";
        $version = ${$varname};
    };

    $version = '' if !defined $version;

    $package =~ s/::/-/g;

    print __x('{program} ({package}) {version}
Copyright (C) 2018, Guido Flohr <guido.flohr@cantanea.com>,
all rights reserved.
This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the Do What the Fuck You Want
to Public License, Version 2, as published by Sam Hocevar. See
http://www.wtfpl.net/ for more details.
', program => $self->programName, package => $package, version => $version);

    exit 0;
}

sub __displayUsage {
    my ($self) = @_;

    print __x("Usage: {program} [OPTION] [INPUTFILE]...\n",
              program => $self->programName);
    print "\n";

    print __(<<EOF);
Generates programs that perform pattern-matching on text.
EOF

    print __(<<EOF);
Mandatory arguments to long options are mandatory for short options too.
Similarly for optional arguments.
EOF

    print "\n";

    print __(<<EOF);
Scanner behavior:
EOF

    print __(<<EOF);
  -e, --encoding=ENOCDING      encoding of input files, default 'UTF-8'
EOF

    print __(<<EOF);
Informative output:
EOF

    print __(<<EOF);
  -h, --help                  display this help and exit
EOF

    print __(<<EOF);
  -V, --version               output version information and exit
EOF

    printf "\n";

    # TRANSLATORS: The placeholder indicates the bug-reporting address
    # for this package.  Please add _another line_ saying
    # "Report translation bugs to <...>\n" with the address for translation
    # bugs (typically your translation team's web or email address).
    print __x("Report bugs at <{URL}>!\n", 
              URL => 'https://github.com/gflohr/Parse-Kayak/issues');

    exit 0;
}

sub __usageError {
    my ($self, $message) = @_;

    if ($message) {
        $message =~ s/\s+$//;
        $message = __x("{program_name}: {error}\n",
                       program_name => $self->programName, error => $message);
    } else {
        $message = '';
    }

    die $message . __x("Try '{program_name} --help' for more information!\n",
                       program_name => $self->programName);
}

sub __yyfatal {
    my ($self, $message) = @_;

    $message =~ s/\s+$//;
    $message = __x("{program_name}: {error}\n",
                   program_name => $self->programName, error => $message);
    
    die $message;
}

sub __yyreadPerl {
    my ($self, $yyinput) = @_;

    my $delim;
    if ($$yyinput =~ s/^\%\{//) {
        $delim = '%}';
    } elsif ($$yyinput =~ s/^\{//) {
        $delim = '}';
    } else {
        $self->__yyfatal(__"internal error: cannot determine code delimiter");
    }

    my $tokenizer = PPI::Tokenizer->new($yyinput);
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
        if ($content =~ /\n/) {
            $code .= join '', @here_doc;
            undef @here_doc;
        }

        # Last thing to do so that the location is correctly calculated.
        $$yyinput = substr $$yyinput, 0, $token->length;
        $last_token = $content;
    }

    # NOT REACHED.
}

1;
