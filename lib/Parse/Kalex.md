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
      * [Comments in the Input](#comments-in-the-input)
   * [PATTERNS](#patterns)
      * [Submatches](#submatches)
      * [Interpolation](#interpolation)
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

## Comments in the Input

Kalex supports C style comments, that is everything inside `/* ... */` usually
gets copied verbatim to the output but is converted to a Perl style comment:

```C
/* Lexical scanner for the XYZ language. */
```

That C style comment becomes:

```Perl
# Lexical scanner for the XYZ language.
```

Kalex should accept comments everywhere flex accepts comments.  If not,
please report it as a bug.  Notable differences to flex are:

* Comments are allowed after start condition declarations.
* Comments are allowed after [name definitions](#name-definitions).

These comments are, however, considered comments on the kalex input and are discarded in the output.

# PATTERNS

The patterns used in the [rules section](#format-of-the-rules-section) are
just regular expressions.  And since Kalex is written in Perl, it is no
wonder that they are *Perl* regular expressions.  You can learn everything 
you want to know about regular expressions with the command `perldoc perlre`
or online at https://perldoc.perl.org/perlre.html.

There are two notable differences to Perl that are both owed to the fact that
the Kalex input is not a Perl program but a description that produces a Perl
program.

## Submatches

The variables `$1, $2, $3, ... $n` that hold captured submatches should not
be used.  They are present but will most probably not contain what you
expect.  The same applies to the magical arrays `@-` and `@+`.

Instead of `$1, $2, $3, ... $n` you can use `$_[1], $_[2], $_[3], ... $_[n]`
in actions.

You can, however, use back references without problems, for example:

```lex
("|').*?\1
```

Even if `$1` will not hold a single or double quote in the above example,
you can refer to it with `\1'.  Actually, the real regular expression is
modified a little bit before being passed to Perl, and the back references
are automatically fixed up to point to the correct submatch.

## Interpolation

In Perl programs, regular expressions are subject to variable interpolation.
For most practical purposes, you can achieve the same effect with [name
definitions](#name-definitions).  You can still interpolate other variables
or even code with `@{[...]}`  but the behavior will most probably look
arbitrary to you.

It is not really arbitrary.  In fact, variable interpolations and code
will be evaluated in the context of a method in the package 
`Parse::Kalex::Lexer` or whatever other package you have specified on the
command-line with the option `--lexer` but you should not rely on that
because this implementation detail may change in the future.

Specifically, keep in mind that the following does *not* work:

```
%%
    my $digit = '[0-9]';
$digit+\.$digit+            return FLOAT, $yytext;
%%
```

The variable `$digit` is lexically scoped to the routine `yylex()` but the
regular expression is compiled in another scope where there is no
variable `$digit`.

On the other hand, this will work as expected:

DIGIT [0-9]
```
%%
$DIGIT+\.$DIGIT+            return FLOAT, $yytext;
%%
```

## Multi-Line Patterns

If the pattern begins with a tilde `~` the following input is treated as a
multi-line pattern.  Example:

%%
~{
    [1-9][0-9]+       # the part before the decimal point
    \(?:    
    \.                # the decimal point
    [0-9]+            # the fractional part.
    )?                # the fractional part is optional.
}gsx                  ECHO

The tilde has the same effect as if Perl had seen the matching operator
`m` in Perl code.
The first character after the tilde `~` is the delimiter, in this case an
opening curly brace.  All nesting delimiters - that are curly braces, 
square brackets, angle bracktes, and parentheses - can be nested.

After the trailing delimiter, you can add all modifiers that Perl support.

See `perldoc perlre` for more information.  Just imagine that instead of 
`~PATTERN` you would have written `$variable =~ mPATTERN`.

# HOW THE INPUT IS MATCHED



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

## The Best Match Is Not Necessarily the Longest

The best match (the one that is selected) in is always the longest match.
If there is more than one rule that produces a match of that length, the
one that comes first in the input file is used.

In Kalex, the first rule that produces a match is selected.  The length
of the match does not matter.

Take the following lexer definition as an example.

```lex
%%
a                          /* discard */
a+                         ECHO;
.|\n                       /* discard */
%%%
```

If you feed the string "aaah" into a flex lexer with that definition, it will
print "aaa", a Kalex lexer will remain silent.

The Kalex lexer will pick the first rule three times because it comes first.
The second rule is effectively useless.

A flex lexer will pick the second rule once, because it produces the longer
match.

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
