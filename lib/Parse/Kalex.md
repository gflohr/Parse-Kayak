# NAME

Kalex - A lexical scanner generator for Perl


# SYNOPSIS

From the command-line:

    $ kalex input.l
    $ kalex --help

Or from Perl:

    $parser = Parse::Kalex->new(%options);
    $parser = Parse::Kalex->newFromArgv(\@ARGV);
    $parser->scan or exit 1;
    $parser->output or exit 1;

<!--TOC-->
# TABLE OF CONTENTS
   * [DESCRIPTION](#description)
   * [INTRODUCTION](#introduction)
   * [EXAMPLES](#examples)
      * [Basic Example](#basic-example)
      * [Counting Lines and Characters](#counting-lines-and-characters)
   * [FORMAT OF THE INPUT FILE](#format-of-the-input-file)
      * [Format of the Definitions Section](#format-of-the-definitions-section)
         * [Name Definitions](#name-definitions)
         * [Start Condition Definitions](#start-condition-definitions)
         * [Indented Text](#indented-text)
         * [%{ CODE %} Sections](#-code-sections)
         * [%top Sections](#-top-sections)
         * [Comments](#comments)
         * [%Option Directives](#-option-directives)
            * [%option yywrap/yynowrap](#-option-yywrap-yynowrap)
      * [Format of the Rules Section](#format-of-the-rules-section)
         * [Rules](#rules)
      * [Format of the User Code Section](#format-of-the-user-code-section)
   * [DIFFERENCES TO FLEX](#differences-to-flex)
      * [No yywrap() By Default](#no-yywrap-by-default)
      * [Name Definitions Define Perl Variables](#name-definitions-define-perl-variables)
   * [COPYRIGHT](#copyright)
   * [SEE ALSO](#see-also)

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
```

The command `kalex japh.pl` has compiled the scanner description 
`japh.l` into a Perl scanner `lex.yy.pl`.  This scanner copies its 
input verbatim to the output but replaces every occurence of the
string "Guido" to "Just another Perl hacker".

## Counting Lines and Characters

The following example is taken from the flex manual:

```lex
    my ($num_lines, $num_chars) = (0, 0);
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
CHAR [a-zA-Z]
%%
${CHAR}${DIGIT}       print "coordinate $^N\n";
.|\n
```

You can omit the curly braces if the character following the variable
name cannot be part of a valid variable name.

```lex
DIGIT [0-9]
CHAR [a-zA-Z]
%%
$CHAR$DIGIT           print "coordinate $^N\n";
.|\n
```

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


### Start Condition Definitions

In the definitions section, you can declare an arbitrary number
of start conditions in one of the following forms:

```lex
%s COND1 COND2
%x XCOND1 XCOND2
```

The form `%s` declares an *inclusive* start condition, the form
`%x` declares an *exclusive* start condition.  See the section
[Start Conditions](#start-conditions) below for more information
on start conditions.

The same restrictions on possible names apply as for [Name
Definitions](#name-definitions) above.

You can place comments after start conditions.

### Indented Text

All indented text in the definitions section is copied verbatim to
the generated scanner.  If you generate a reentrant scanner, the
text is inserted right after the `package` definition in the generated
code.

### %{ CODE %} Sections

All text enclosed in `%{ ...%}` is also copied to the output without
the enclosing delimiters, but the enclosed text must be valid Perl
code.

### %top Sections

A `%top` section can contain arbitrary Perl code:

```lex
%top {
    use strict;

    my $foo = 1;
    my $bar = 2;
}
%%
RULE...
```

The enclosed code will be placed at the top of the file, outside
of a possible `package` statement for re-entrant parsers.

Multiple `%top` sections are allowed.  Their order is preserved.

### Comments

Everything enclosed in `/* ... */` is treated as a comment and copied
to the output.  The comment is converted to a Perl comment though.

### %Option Directives

Option are defined with the `%option` directive

```lex
%option noyywrap outfile="parse.pl"
```

Boolean options can be preceded by "no" to negate them.  Options
that take a value receive the value in a single- or double-quoted
string.  Escape sequences like `\n` are only expanded in
double-quoted strings.

The following options are supported;

#### %option yywrap/yynowrap

Activates or deactivates the yywrap mechanism.  See
[The yywrap() Function](#the-yywrap-function) below.  The
default is false.

## Format of the Rules Section

### Rules

The rules section consists an arbitrary number of rules defined
as:

```lex
<SC1,SC2,SC3>pattern action
```

The first part of the rule is an optional comma-separated list of 
start conditions enclosed in angle brackets.  If present, the
rule is only active in one of the listed start conditions.

[Start Conditions](#start-conditions) below for more information
on start conditions.

The pattern can be almost any Perl regular expression.  See
[Patterns](#patterns) below for more information.

The third optional part is an action.  In any of the following
two forms:

```lex
$(DIGIT)+\.($DIGIT)    {
                           return FLOAT => "$_[1].$_[2]";
                       }
\n                     return NEWLINE => "\n";
```

Instead of `{ ... }` you can also use `%{ ... %}`.

See [Actions](#actions) below for more information on actions.

Since start conditions and actions are optional, a rule can also
consist of a pattern only.

## Format of the User Code Section

The user code section is copied verbatim to the generated scanner.

If the scanner is not reentrant, it will be preceded by

```perl
package main;

no strict;
```

That means that you should put a `use strict;` at the beginning
of your user code section if you want to enable strictness.

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
