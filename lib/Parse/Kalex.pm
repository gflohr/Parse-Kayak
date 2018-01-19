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

sub new {
    bless {}, shift;
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

sub run {
    my ($self) = @_;

    return $self;
}

sub output {
    die 'todo';
}

sub programName { $0 }

sub __getOptions {
    my ($self, $argv) = @_;

    my %options;

    Getopt::Long::Configure('bundling');
    GetOptionsFromArray($argv,

        # Informative output.
        'h|help' => \$options{help},
        'V|version' => \$options{version},
    );

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

1;
