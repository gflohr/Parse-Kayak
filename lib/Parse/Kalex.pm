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

sub new {
    my ($class, $options, @input_files) = @_;

    @input_files = ('') if !@input_files;
    my $self = {
        __options => {%$options},
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

sub __updateLocation {
    my ($self, $consumed) = @_;

    if (defined $self->{__last}) {
        if ($self->{__last} =~ s/(.*\n)//m) {
            $self->{__lineno} += $1 =~ y/\n/\n/;
        }
        $self->{__charno} += length $self->{__last};
    };
    $self->{__last} = $self->{__current};
    $self->{__current} = $consumed;

    return $self;
}

sub __consumeWhitespace {
    my ($self) = @_;

    if ($self->{__input} =~ s/^([ \011-\015]+)//) {
        $self->__updateLocation($1);
    }

    return $self;
}

sub __nextChar {
    my ($self) = @_;

    if ($self->{__input} =~ s/^(.)//) {
        return 'ERROR', $1;
    }

    return YYEOF;
}

sub __yylexINITIAL {
    my ($self) = @_;

    $self->__consumeWhitespace;

    if ($self->{__input} =~ s/^(%%)//) {
        return SEPARATOR => $1;
    }

    return $self->__nextChar;
}

sub __yylex {
    my ($self) = @_;

    if (!length $self->{__input}) {
        my $filename = shift @{$self->{__todo}};
        return YYEOF if !defined $filename;

        my $fh;
        my $encoding = $self->{__options}->{encoding};
        if (!length $filename) {
            $filename = __"<standard input>";
            binmode STDIN, ":$self->{__options}->{encoding}";
            $fh = \*STDIN;
        } else {
            open $fh, "<:encoding($encoding)", $filename
                or $self->__fatal(__x("error opening '{filename}' for"
                                      . " reading: {error}!",
                                      filename => $filename, error => $!));
        }

        $self->{__filename} = $filename;
        $self->{__lineno} = 1;
        $self->{__charno} = 1;
        $self->{__input} = join '', $fh->getlines;
        $self->{__state} = ['INITIAL'];
    }

    my $method = '__yylex' . $self->{__state}->[-1];

    my ($token, $consumed) = $self->$method;
    $self->__updateLocation($consumed);
    if (!defined $consumed && @{$self->{__todo}}) {
        # Next input file.
        return $self->{__yylex};
    }

    return $token, $consumed;
}

sub __yyerror {
    my ($self) = @_;

    if (defined $self->{__current}) {
        warn __x("{filename}:{lineno}:{charno}: syntax error at or near"
                 . " '{token}'.\n",
                 filename => $self->{__filename}, lineno => $self->{__lineno},
                 charno => $self->{__charno}, token => $self->{__current});
    } else {
        warn __x("{filename}:{lineno}:{charno}: syntax error at beginning"
                 . " of input.\n",
                 filename => $self->{__filename}, lineno => $self->{__lineno},
                 charno => $self->{__charno}, token => $self->{__current});
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

    my @input_files = @{$self->{__input_files}};
    $self->{__todo} = \@input_files;
    $self->{__input} = '';
    delete $self->{__last};

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
