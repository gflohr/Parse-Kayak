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

use constant YYEOF => ('', undef);

my $IDENT = '[_a-zA-Z][_a-zA-Z0-9]*';

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
        or $self->fatal(__"POP called but start condition stack is empty!\n");

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
        $self->fatal(__x("undefined start condition",
                        condition => $self->{__state}->[-1]));        
    }

    my $method = '__yylex' . $state;
    if (!$self->can($method)) {
        $self->fatal(__x("unknown start condition '{condition}'",
                        condition => $self->{__state}->[-1]));
    }

    return $method;
}

sub __yyconsumeWhitespace {
    my ($self, $allow_newline) = @_;

    if ($allow_newline) {
        $self->{__yytext} =~ s/^([ \011-\015]+)//o;
    } else {
        $self->{__yyinput} =~ s/^([ \011\013-\015]+)//o;
    }

    return $self;
}

sub __yynextChar {
    my ($self) = @_;

    if ($self->{__input} =~ s/^(.)//o) {
        return $1, $1;
    }

    return YYEOF;
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
        return '>', '>';
    } elsif ($self->{__yyinput} =~ s/^\n//o) {
        $self->YYPOP;
        return NEWLINE => "\n";
    }

    return $self->__yynextChar;
}

sub __yylexINITIAL {
    my ($self) = @_;

    if ($self->{__yyinput} =~ s/^(%%)//o) {
        return SEPARATOR => $1;
    } elsif ($self->{__yyinput} =~ s/^(%[sx])//o) {
        $self->YYPUSH('CONDITIONS');
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
        $self->__fatal(__x("invalid encoding '{encoding}'!",
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

sub __fatal {
    my ($self, $message) = @_;

    $message =~ s/\s+$//;
    $message = __x("{program_name}: {error}\n",
                   program_name => $self->programName, error => $message);
    
    die $message;
}

1;
