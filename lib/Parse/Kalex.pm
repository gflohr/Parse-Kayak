#! /bin/false

# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.

package Parse::Kalex;

use strict;

use Locale::TextDomain qw(kayak);
use Getopt::Long 2.36 qw(GetOptionsFromArray);
use Parse::Kalex::Parser;
use IO::Handle;
use PPI::Tokenizer;
use File::Spec;

use Parse::Kalex::Generator;

use constant YYEOF => ('', undef);

my $IDENT = '[_a-zA-Z][_a-zA-Z0-9]*';
my $WS = '[ \011\013-\015]';
my $WSNEWLINE = '[ \011-\015]';
my $NOWS = '[^ \011-\015]';
my $OPTION = '[-_a-zA-Z0-9]+';

sub new {
    my ($class, $options, @input_files) = @_;

    if (@_ == 1) {
        $options = {$class->__defaultOptions};
    } elsif (!ref $options) {
        unshift @input_files, $options;
        $options = {$class->__defaultOptions};
    }
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

# FIXME! This was a thinko.  We need the location constantly and not just for
# error message.  Track the location instead so that returning it is cheap.
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
    my ($self, $multi_line) = @_;

    if ($multi_line) {
        $self->{__yyinput} =~ s/^($WSNEWLINE*\n)//o;
        return $1;
    } else {
        $self->{__yyinput} =~ s/^($WS+)//o;
        return $1;
    }

    return '';
}

sub __yynextChar {
    my ($self) = @_;

    if ($self->{__yyinput} =~ s/^(.|\n)//o) {
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
        my $code = eval { $self->__yyreadPerl(\$self->{__yyinput}) };
        if ($@) {
            $self->__yyfatalParseError($@);
        }
        $self->YYPOP();
        # FIXME! This will confuse the current location counter!
        $self->__yyconsumeWhitespace(1);
        return ACTION => $code;
    } elsif ($self->{__yyinput} =~ /^\%\{/o) {
        # %{ ... %}
        my $code = $self->__yyreadPerl(\$self->{__yyinput});
        if ($@) {
            $self->__yyfatalParseError($@);
        }
        $self->YYPOP();
        # FIXME! This will confuse the current location counter!
        $self->__yyconsumeWhitespace(1);
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
        return PATTERN => '';
    } elsif ($self->{__yyinput} =~ s/^([^\\\[\( \011-\015]+)//) {
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^(\\[1-9][0-9]*)//o) {
        # Backreference.  They must be counted.
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^(\\.)//o) {
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^(\[\]?)//o) {
        # Character class.  Character classes cannot be empty.  That means
        # that a closing bracket does not have to be escaped if it is the
        # first character.
        $self->YYPUSH('REGEXCC');
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^(\(\??)//o) {
        # This is a chunk of its own so that we can count parentheses.
        return PATTERN => $1;
    } elsif ($self->{__yyinput} =~ s/^\n//o) {
        $self->YYPOP();
        return PATTERN => '';
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
        $self->YYPUSH('USER_CODE');
        return SEPARATOR => '%%';
    } else {
        $self->YYPUSH('ACTION');
        $self->YYPUSH('REGEX');
        return $self->__yylexREGEX;
    }

    return $self->__yynextChar;
}

sub __yylexUSER_CODE {
    my ($self) = @_;

    $self->YYPOP();
        
    my $code = $self->{__yyinput};
    $self->{__yyinput} = '';

    return YYEOF if !length $code;

    return USER_CODE => $code;
}

sub __unquoteGeneral {
    my ($self, $string) = @_;

    $string =~ s/\\(.)/$1/gs;

    return $string;
}

sub __yylexOPTION_VALUE {
    my ($self) = @_;

    $self->__yyconsumeWhitespace;

    if ($self->{__yinput} =~ s/^"([^\\"]*(?:\\"[^\\"]*)*)"//) {
        $self->YYPOP;
        return OPTION_VALUE => $self->__unquoteGeneral($1);
    } elsif ($self->{__yinput} =~ s/^'([^\\']*(?:\\'[^\\']*)*)'//) {
        $self->YYPOP;
        return OPTION_VALUE => $self->__unquoteGeneral($1);
    } elsif ($self->{__yyinput} =~ s/^($NOWS)//) {
        $self->YYPOP;
        return OPTION_VALUE => $1;
    }

    return $self->__yynextChar;
}

sub __yylexOPTION {
    my ($self) = @_;

    $self->__yyconsumeWhitespace;

    if ($self->{__yyinput} =~ s/^($OPTION)$WS*//) {
        return OPTION_NAME => $1;
    } elsif ($self->{__yyinput} =~ s/^=//) {\
        $self->YYPUSH('OPTION_VALUE');
        return $self->__yylex;
    } elsif ($self->{__yyinput} =~ s/^\n//) {
        $self->YYPOP;
        return $self->__yylex;
    }

    return $self->__yynextChar;
}

sub __yylexNAME {
    my ($self) = @_;

    my $ws = $self->__yyconsumeWhitespace;
    return $self->__yynextChar if !length $ws;

    if ($self->{__yyinput} =~ s/^($NOWS+)//) {
        # FIXME! Allow comments!
        $self->YYPOP();
        return REGEX => $1;
    }

    return $self->__yynextChar;
}

sub __yylexINITIAL {
    my ($self) = @_;

    if ($self->{__yyinput} =~ s/^%%$WS*\n?//o) {
        $self->YYPUSH('RULES');
        return SEPARATOR => '%%';
    } elsif ($self->{__yyinput} =~ s/^([_a-zA-Z][_a-zA-Z0-9]*)//) {
        $self->YYPUSH('NAME');
        return NAME => $1;
    } elsif ($self->{__yyinput} =~ s/^(%[sx])//o) {
        $self->YYPUSH('FIRST_CONDITION_DECLS');
        return SC => $1;
    } elsif ($self->{__yyinput} =~ s{^/\*}{}o) {
        $self->{__yyinput} = '/*' . $self->{__yyinput};
        if ($self->{__yyinput} !~ s{(/\*.*?\*/)$WS?\n}{}o) {
            $self->__yyfatalParseError(__("cannot find comment delimiter '*/'"
                                          . " before end of file"));
        } else {
            return COMMENT => $1;
        }
    } elsif ($self->{__yyinput} =~ s/^$WSNEWLINE*\n//o) {
        return $self->__yylex();
    } elsif ($self->{__yyinput} =~ s/^((?:$WS+.*\n)+)//o) {
        return DEF_CODE => $1;
    } elsif ($self->{__yyinput} =~ /^%\{/) {
        my $code = eval { $self->__yyreadPerl(\$self->{__yyinput}) };
        if ($@) {
            $self->__yyfatalParseError($@);
        }
        return DEF_CODE => $code;
    } elsif ($self->{__yyinput} =~ s/^\%top$WSNEWLINE*\{//o) {
        $self->{__yyinput} = '{' . $self->{__yyinput};
        my $code = eval { $self->__yyreadPerl(\$self->{__yyinput}) };
        if ($@) {
            $self->__yyfatalParseError($@);
        }
        return TOP_CODE => $code;
    } elsif ($self->{__yyinput} =~ s/^\%option$WS*//o) {
        $self->YYPUSH('OPTION');
        return OPTION => 'OPTION';
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

sub scan {
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
    $parser->YYData->{generator} = Parse::Kalex::Generator->new($self);
    $parser->YYData->{lexer} = $self;
    my $result = $parser->YYParse(yylex => $yylex,
                                  yyerror => $yyerror,
                                  yydebug => $ENV{YYDEBUG});
    delete $self->{__yyinput};

    return if !defined $result;

    $self->{__generator} = $parser->YYData->{generator};
    return if $self->{__generator}->errors;

    return $self;
}

sub outputFilename {
    shift->{__outname};
}

sub output {
    my ($self) = @_;

    my $generator = $self->{__generator};
    if (!$generator) {
        $self->__yyfatal(__"output() called before scan()");
    }

    my %options = %{$self->{__yyoptions}};
    if (defined $options{outfile} && defined $options{stdout}) {
        $self->__yyfatal(__("'\%option stdout' is mutually exclusive with"
                            . " the command-line option '--outfile'"));
    }
    $options{outfile} = defined $options{package}
        ? $options{package} . '.pm' : 'lex.yy.pl';

    my $encoding = $options{encoding};
    
    my ($fh, $outname);
    if ($options{stdout}) {
        $outname = __"<standard output>";
        $fh = \*STDOUT;
    } else {
        $outname = $options{outfile};
        open $fh, ">:encoding($encoding)", $outname
            or $self->__yyfatal(__x("error opening '{filename} for writing:'"
                                    . " {error}!",
                                    filename => $outname, error => $!));
    }

    $self->{__outname} = $outname;
    $self->{__outfh} = $fh;

    my $output = eval { $generator->generate(%options) };
    $self->__yyfatal($@) if $@;

    $fh->print($output)
        or $self->__yyfatal(__x("error writing to '{filename}:'"
                                . " {error}!",
                                filename => $outname, error => $!));
    if (!$options{stdout}) {
        $fh->close
            or $self->__yyfatal(__x("error closing '{filename}:'"
                                . " {error}!",
                                filename => $outname, error => $!));

    }

    return $self;
}

sub programName { $0 }

sub __defaultOptions {
    encoding => 'UTF-8',
}

sub __getOptions {
    my ($self, $argv) = @_;

    my %options = $self->__defaultOptions;

    Getopt::Long::Configure('bundling');
    GetOptionsFromArray($argv,
        # Files
        'o|outfile=s' => \$options{outfile},
        't|stdout' => \$options{stdout},

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

    if (defined $options{outfile} && defined $options{stdout}) {
        $self->__yyfatal(__("the options '--outfile' and '--stdout' are"
                           . " mutually exclusive!"));
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

    print "\n";

    print __(<<EOF);
Mandatory arguments to long options are mandatory for short options too.
Similarly for optional arguments.
EOF

    print "\n";

    print __(<<EOF);
Files:
EOF

    print __(<<EOF);
  -o, --outfile=OUTFILE        write scanner to OUTFILE instead of lex.yy.pl
EOF

    print __(<<EOF);
  -t, --stdout                 write scanner to standard output
EOF

    print "\n";

    print __(<<EOF);
Scanner behavior:
EOF

    print __(<<EOF);
  -e, --encoding=ENOCDING      encoding of input files, default 'UTF-8'
EOF

    print "\n";

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
    $message = __x("{location}: {error}\n",
                   location => $self->programName, error => $message);
    
    die $message;
}

sub __yyfatalParseError {
    my ($self, $message) = @_;

    my $location = $self->yylocation;

    $message =~ s/\s+$//;
    $message = __x("{location}: {error}\n",
                   location => $location, error => $message);

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
                    $$yyinput = substr $$yyinput, 2;
                    return $code;
                }
                if ('}' eq $delim && !$nesting) {
                    $$yyinput = substr $$yyinput, 1;
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

        # Last thing to do so that the location is correctly calculated.
        $$yyinput = substr $$yyinput, $token->length;

        $last_token = $content;
    }

    # NOT REACHED.
}

1;
