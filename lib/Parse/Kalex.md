# NAME

Parse::Kalex - Base class for kalex scanners

# SYNOPSIS

From the command-line:

    $ kalex input.l
    $ kalex --help

Or from Perl:

    $parser = Parse::Kalex->new(%options);
    $parser = Parse::Kalex->newFromArgv(\@ARGV);
    $parser->scan or exit 1;
    $parser->output or exit 1;

# DESCRIPTION

Kalex is the scanning counterpart of [Kayak](Kayak.md).  It can be
used to generate lexical analyzers (also known as tokenizers or
scanners) for all kinds of parsers.

Its command-line interface `kalex` is a Perl equivalent to `flex(1)`.
This manual is on purpose structured in a similar fashion as the flex
manual so that you can easily compare features.

# INTRODUCTION

Kalex reads the given scanner description from the given input files,
or standard input if no input files were specified.  The description 
mainly consists of *rules* with a regular expression to match on the 
left-hand side and an optional action to execute for each match on 
the right-hand side. The action consists of arbitrary Perl code.  
The match text and possibly captured sub matches are available as 
Perl variables.

# EXAMPLES

## Basic Example

Take this input file `japh.l`:

```lex
%%
Guido                      print "just another Perl hacker";
%%
yylex;
```

Generate and run the scanner.

```sh
$ kalex japh.l
$ echo "I am Guido" | perl lex.yy.pl
I am just another Perl hacker
Undefined subroutine &main::yywrap called at Parse/Kalex/Snippets/main.pm line 31, <STDIN> line 1.
```

The command `kalex japh.pl` has compiled the scanner description 
`japh.l` into a Perl scanner `lex.yy.pl`.  This scanner copies its 
input verbatim to the output but replaces every occurence of the
string "Guido" to "Just another Perl hacker".

## Counting Lines and Characters

The following example is taken from the flex manual:

```lex
    my ($num_lines, $num_chars) = (0, 0);

%option noyywrap
%%
\n      ++$num_lines; ++$num_chars;
.       ++$num_chars;
%%
yylex;
print "# of lines = $num_lines, # of characters= $num_chars\n";
```

This scanner counts the number of characters and the number of lines in its
input. It produces no output other than the final report on the number of
lines and characters in the input stream.

# FORMAT OF THE INPUT FILE

The overall format of the kalex input file is:

```lex
definitions
%%
rules
%%
user code
```

All sections can be empty and the user code section is optional.  The
smallest valid input to kalex is therefore a lone `%%`.  That will
produce a scanner which copies its standard input to standard output.

## Format of the Definitions Section

In the definitions section you can define various properties and 
aspects of the scanner.

### Name Definitions

A name definition takes the following form:

```
name definition
```

`name` must be a valid Perl identifier.  Perl identifiers may start
with one of the letters "a" to "z", "A" to "Z" or the underscore "_",
followed by an arbitrary number of these characters.

Non-ASCII characters are also allowed but it depends on your version
of Perl and your user code whether such identifiers are accepted
by Perl.  Try `perldoc utf8` for details.

The definition must be a valid regular expression fragment.
Whitespace inside of the fragment must either be backslash escaped or
part of a character class:

```
VARIABLE   foo\ bar[ ]baz
```

The pattern is the string "foo bar baz".  The first space character
is escaped, the second one is part of a character class.

You can reference the variable in a rule like this:

```lex
DIGIT [0-9]
CHAR [a-z][A-Z]
%%
${DIGIT}${CHAR}       print "coordinate $^N\n";
.|\n
```

You can omit the curly braces if the character following the variable
name cannot be part of a valid variable name.

Using variable references, capturing parentheses, or back references
inside definitions will lead to undefined behavior of the scanner.
All of the following definitions must be avoided:

```lex
HAS_VARIABLE   Name: \$name
HAS_CAPTURE    $#([0-9+);
HAS_BACKREF    (["']).*?\1
```

Non-capturing parentheses (that are parentheses followed by a
question mark "?") are allowed:

```
TAG          <[a-z]+(?: [a-z]+=".*?"])>
```

Comments (`/* ... */`) after the definition are allowed and are
discarded.  They are *not* copied to the generated scanner.  Note
that they will possibly confuse syntax highlighters because comments
are not allowed after name definitions for flex and lex.

### Indented Text

All indented text in the definitions section is copied verbatim to
the generated scanner.  If you generate a reentrant scanner, the
text is inserted right after the `package` definition in the generated
code.

### %{ CODE %} Sections

All text enclosed in `%{ ...%}` is also copied to the output without
the enclosing delimiters, but the enclosed text must be valid Perl
code.

### Commments

Everything enclosed in `/* ... */` is treated as a comment and copied
to the output.  The comment is converted to a Perl comment though.

# DIFFERENCES TO FLEX

## No yywrap() By Default

Kalex uses yywrap() in exactly the same manner as flex but it assumes
by default that you want to scan just one input stream and does not
attempt to invoke yywrawp() unless you explicitely specify it with

```lex
%option yywrap
```

That avoids the necessity to add `%option noyywrap` to your input
files for the normal use case.

## Name Definitions Define Perl Variables

Name definitions are identical in kalex and flex but the way you use them
in patterns differ.  In kalex you use regular Perl syntax:

```lex
DIGIT [0-9]
%%
\&#${DIGIT}*;
```

You can also assign to them inside actions but then you have to call
`yyrecompile()` resp. `$lexer->yyrecompile()` from within the scanner
so that the regular expressions are updated.

# COPYRIGHT

Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
all rights reserved.

# SEE ALSO

kalex(1), perl(1)
