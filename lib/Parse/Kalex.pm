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

use Parse::Kalex::Lexer;
use Parse::Kalex::Generator;

use constant YYEOF => ('', undef);

my $IDENT = '[^\000-\100\133-\136\140\173-\177]'
            . '[^\000-\057\072-\100\133-\136\140\173-\177]*';
my $WS = '[ \011\013-\015]';
my $WSNEWLINE = '[ \011-\015]';
my $NOWS = '[^ \011-\015]';
my $OPTION = '[-_a-zA-Z0-9]+';

sub new {
    my ($class, $options, @input_files) = @_;

    if (@_ > 2 && !ref $options) {
        unshift @input_files, $options;
        $options = {};
    }
    my %options = $class->__defaultOptions;
    foreach my $option (keys %$options) {
        $options{$option} = $options->{$option};
    }

    my $self = {
        __options => \%options,
        __input_files => \@input_files,
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

sub __validateStartCondition {
    my ($self, $state) = @_;

    if (!defined $state || !length $state) {
        $self->__fatal(__x("undefined start condition", condition => $state));        
    }

    my $method = '__yylex' . $state;
    if (!$self->can($method)) {
        $self->__fatal(__x("unknown start condition '{condition}'",
                           condition => $state));
    }

    return $method;
}

sub __error {
    my ($self) = @_;

    my $lexer = $self->{__lexer};
    my $filename = $lexer->{yyinname};
    my $location = $filename . ':' . $lexer->yylocation;

    if (defined $lexer->{yypos}) {
        warn __x("{location}: syntax error near '{token}'.\n",
                 location => $location, token => $lexer->{yytext});
    } else {
        warn __x("{location}: syntax error at beginning of input.\n",
                 location => $location);
    }

    return $self;
}

sub scan {
    my ($self) = @_;

    my $lexer = $self->{__lexer} = Parse::Kalex::Lexer->new(@{$self->{__input_files}});

    my $yylex = sub {
        return $lexer->yylex;
    };

    my $yyerror = sub {
        return $self->__error;
    };

    my $parser = Parse::Kalex::Parser->new;
    my %options;
    foreach my $option (qw(debug package line strict)) {
        if (exists $self->{__options}->{$option}) {
            $options{$option} = $self->{__options}->{$option};
        }
    }
    $parser->YYData->{generator} = Parse::Kalex::Generator->new($self,
                                                                %options);

    $parser->YYData->{kalex} = $self;
    my $result = $parser->YYParse(yylex => $yylex,
                                  yyerror => $yyerror,
                                  yydebug => $ENV{YYDEBUG});

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

    my %options = %{$self->{__options}};

    if (!$generator) {
        $self->__fatal(__"output() called before scan()");
    }

    $generator->mergeOptions;

    if (defined $options{outfile} && defined $options{stdout}) {
        $self->__fatal(__("'\%option stdout' is mutually exclusive with"
                          . " the command-line option '--outfile'"));
    }

    if (!defined $options{outfile}) {
        $options{outfile} = defined $generator->package
            ? 'lex.yy.pm' : 'lex.yy.pl';
    }

    my $outname;
    if ($options{stdout}) {
        $outname = __"<standard output>";
    } else {
        $outname = $options{outfile};
    }

    $self->{__outname} = $outname;

    my $output = eval { $generator->generate };
    $self->__fatal($@) if $@;

    my $encoding = $options{encoding};
    
    my ($fh);
    if ($options{stdout}) {
        $fh = \*STDOUT;
    } else {
        open $fh, ">:encoding($encoding)", $outname
            or $self->__fatal(__x("error opening '{filename} for writing:'"
                                  . " {error}!",
                                  filename => $outname, error => $!));
    }

    $fh->print($output)
        or $self->__fatal(__x("error writing to '{filename}:'"
                              . " {error}!",
                              filename => $outname, error => $!));
    if (!$options{stdout}) {
        $fh->close
            or $self->__fatal(__x("error closing '{filename}:'"
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
        # Debugging
        'd|debug' => \$options{debug},

        # Files
        'o|outfile=s' => \$options{outfile},
        't|stdout' => \$options{stdout},

        # Scanner behavior
        'e|encoding=s' => \$options{encoding},
        'yylineno' => \$options{yylineno},

        # Generated code
        'p|package=s' => \$options{package},
        'L|noline' => \$options{noline},
        'strict' => \$options{strict},

        # Informative output.
        'h|help' => \$options{help},
        'V|version' => \$options{version},
    );
    $options{line} = 1 if delete $options{noline};

    if ($options{encoding} =~ /[\\\)]/) {
        $self->__fatal(__x("invalid encoding '{encoding}'!",
                           encoding => $options{encoding}));
    }

    if (defined $options{outfile} && defined $options{stdout}) {
        $self->__fatal(__("the options '--outfile' and '--stdout' are"
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

    print __x('{program} (Parse-Kayak) {version}
Copyright (C) 2018, Guido Flohr <guido.flohr@cantanea.com>,
all rights reserved.
This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the Do What the Fuck You Want
to Public License, Version 2, as published by Sam Hocevar. See
http://www.wtfpl.net/ for more details.
', program => $self->programName, version => $version);

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
Debugging:
EOF

    print __(<<EOF);
  -d, --debug                 enable debug mode in scanner
EOF

    print "\n";

    print __(<<EOF);
Files:
EOF

    print __(<<EOF);
  -o, --outfile=OUTFILE       write scanner to OUTFILE instead of lex.yy.pl
EOF

    print __(<<EOF);
  -t, --stdout                write scanner to standard output
EOF

    print "\n";

    print __(<<EOF);
Scanner behavior:
EOF

    print __(<<EOF);
  -e, --encoding=ENOCDING     encoding of input files, default 'UTF-8'
EOF

    print __(<<EOF);
      --yylineno              track line count in yylineno
EOF

    print "\n";

    print __(<<EOF);
Generated code:
EOF

    print __(<<EOF);
  -p, --package=PACKAGE       generate reentrant scanner in package PACKAGE
EOF

    print __(<<EOF);
  -L, --noline                suppress #line directives in scanner
EOF

    print __(<<EOF);
      --strict                enable strict mode in scanner
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

sub __fatal {
    my ($self, $message) = @_;

    $message =~ s/\s+$//;
    $message = __x("{location}: {error}\n",
                   location => $self->programName, error => $message);
    
    die $message;
}

sub __fatalParseError {
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
        $self->__fatal(__"internal error: cannot determine code delimiter");
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

sub __yyReadRuleRegex {
    my ($self, $yyinput) = @_;

    my @location = $self->yylocation;

    # Make PPI::Tokenizer see a pattern match.
    substr $$yyinput, 0, 1, 'm';
    my $tokenizer = PPI::Tokenizer->new($yyinput);
    my $token = $tokenizer->get_token;

    # Sort the modifiers so that our generated source code will not contain
    # any unsavory words, unless explicitely desired by the author.
    my $modifiers = join '', sort keys %{$token->get_modifiers};
    my $match_string = "(?$modifiers:" . $token->get_match_string . ")";

    $self->{__yytext} = $token->content;
    substr $self->{__ytext}, 0, 1, '~';

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

    $$yyinput = substr $$yyinput, $token->length;

    return $regex;
}

sub __readDefRegex {
    my ($self) = @_;

    my $pattern = '';
    while (length $self->{__yyinput}) {
        if ($self->{__yyinput} =~ s/^([^ \011-\015\\\[]]+)//) {
            $pattern .= $1;
        } elsif ($self->{__yyinput} =~ s/^(\\.)//) {
            $pattern .= $1;
        } elsif ($self->{__yyinput} =~ s/^\[//) {
            $pattern .= '[' . $self->__readDefCC;
        } elsif ($self->{__yyinput} =~ s/^\n//) {
            return $pattern;
        } elsif ($self->{__yyinput} =~ s/^($WS+)//) {
            last;
        } elsif ($self->{__yyinput} =~ s/^(.)//) {
            $pattern .= $1;
        }
    }
 
    # Consume whitespace and comments.
    while (length $self->{__yyinput}) {
        $self->{__yyinput} =~ s/^$WS+//;
        $self->{__yyinput} =~ s{/\*.*?\*/}{}s;
        last if $self->{__yyinput} =~ s/^\n//;
    }

    return $pattern;
}

sub __readDefCC {
    my ($self) = @_;

    my $class = '';
    while (length $self->{__yyinput}) {
        if ($self->{__yyinput} =~ s/^(\\.)//o) {
            $class .= $1;
        } elsif ($self->{__yyinput} =~ s/^\]//o) {
            $class .= ']';
            return $class;
        } elsif ($self->{__yyinput} =~ s/^\n//o) {
            return $class;
        } elsif ($self->{__yyinput} =~ s/^(.)//o) {
            $class .= $1;
        }
    }
    
    if (!length $self->{__yyinput}) {
        # FIXME!
        die "unterminated character class";
    }

    return $class;
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

1;
