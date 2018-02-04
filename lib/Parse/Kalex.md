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
      * [ANCHORS ("^" and "$")](#anchors-and-)
      * [Multi-Line Patterns](#multi-line-patterns)
   * [HOW THE INPUT IS MATCHED](#how-the-input-is-matched)
      * [How It Really Works](#how-it-really-works)
         * [Captures](#captures)
         * [Backreferences](#backreferences)
      * [Performance Considerations](#performance-considerations)
      * [Alternations](#alternations)
   * [ACTIONS](#actions)
      * [ECHO](#echo)
      * [YYBEGIN](#yybegin)
      * [YYPUSH](#yypush)
      * [YYPOP](#yypop)
      * [REJECT](#reject)
   * [FREQUENTLY ASKED QUESTIONS](#frequently-asked-questions)
      * [Quantifier Follows Nothing In Regex](#quantifier-follows-nothing-in-regex)
      * [Unknown regexp modifier "/P" at](#unknown-regexp-modifier-p-at)
   * [DIFFERENCES TO FLEX](#differences-to-flex)
      * [No yywrap() By Default](#no-yywrap-by-default)
      * [BEGIN is YYBEGIN](#begin-is-yybegin)
      * [YYPUSH and YYPOP](#yypush-and-yypop)
      * [The Best Match Is Not Necessarily the Longest](#the-best-match-is-not-necessarily-the-longest)
      * [Name Definitions Define Perl Variables](#name-definitions-define-perl-variables)
      * [REJECT is Less Expensive](#reject-is-less-expensive)
      * [Code Following REJECT is Allowed](#code-following-reject-is-allowed)
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

Kalex reads the given scanner description from the given input sources,
or standard input if no input sources were specified.  The description 
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
followed by an arbitrary number of these characters or the digits
"0" to "9".

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

The same restrictions for possible names apply as for [Name
Definitions](#name-definitions) above.

You can place comments after start conditions.

### Indented Text

All indented text in the definitions section is copied verbatim to
the generated scanner.  If you generate a [reentrant
scanner](#reentrant-scanners), the
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
of a possible `package` statement for reentrant parsers.

Multiple `%top` sections are allowed.  Their order is preserved.

### Comments

C-style comments (`/* ... */`) must start in the first column of a line.
There are converted to a Perl comment and copied to the output.

C-style comments that do *not* start in the first column are treated as
[indented text](#indented-text) and are copied verbatim to the output,
where they will almost inevitably cause a syntax error.  Use Perl
style comments in indented text!

### %Option Directives

Options are defined with the `%option` directive

```lex
%option noyywrap outfile="parse.pl"
```

Boolean options can be preceded by "no" to negate them.  Options
that take a value receive the value in a single- or double-quoted
string.  Escape sequences like `\n` are only expanded in
double-quoted strings. (FIXME!)

The following options are supported;

#### %option yywrap/yynowrap

Activates or deactivates the yywrap mechanism.  See
[The yywrap() Function](#the-yywrap-function) below.  The
default is false.

## Format of the Rules Section

### Rules

The rules section consists of an arbitrary number of rules defined
as:

```lex
<SC1,SC2,SC3>pattern action
```

The first part of the rule is an optional comma-separated list of 
start conditions enclosed in angle brackets.  If present, the
rule is only active in one of the listed start conditions.

See [Start Conditions](#start-conditions) below for more information
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
variable `$digit` defined.

On the other hand, this will work as expected:

```
DIGIT [0-9]
%%
$DIGIT+\.$DIGIT+            return FLOAT, $yytext;
%%
```

## ANCHORS ("^" and "$")

All kalex patterns are compiled with the `/m` modifier.  That means that
`^` stands for the beginning of a line or the beginning of input, and
`$` stands for the end of a line or the end of input.  See the section
[How the Input Is Matched](#how-the-input-is-matched) for more information.

## Multi-Line Patterns

If the pattern begins with a tilde `~` the following input is treated as a
multi-line pattern.  Example:

```lex
%%
~{
    [1-9][0-9]+       # the part before the decimal point
    \(?:    
    \.                # the decimal point
    [0-9]+            # the fractional part.
    )?                # the fractional part is optional.
}gsx                  ECHO
```

The tilde has the same effect as if Perl had seen the matching operator
`m` in Perl code.
The first character after the tilde `~` is the delimiter, in this case an
opening curly brace.  All nesting delimiters - that are curly braces, 
square brackets, angle bracktes, and parentheses - can be nested.

After the trailing delimiter, you can add all modifiers that Perl support.

See `perldoc perlre` for more information.  Just imagine that instead of 
`~PATTERN` you would have written `$variable =~ mPATTERN`.

# HOW THE INPUT IS MATCHED

The generated scanner matches its input against the patterns provided in
the rules section, stopping at the first match.  The patterns are 
anchored to the position where the last match ended.  The generated
`yylex()` function roughly looks like this:

```perl
sub yylex {
    while (pos() < length $yytext) {
        $yytext =~ /\G$pattern_for_this_start_condition/gm;
        execute_action();
    }
}
```

If a rule matches but the match is empty, you will create  an endless 
loop unless you change the start condition in the action code or return.
Currently, there is no warning about empty matches.

The matched text is availabe in the variable `$yytext` or in the variable
`$^N`.  The difference is that `$^N` will only contain the matched text
for the current rule while `$yytext` may contain prefixed text resulting
froma a preceding invocation of [`yymore()`](#yymore).

Then the [action](#actions) for the matching rule is executed.  Remember
that there is always a default rule appended to the user supplied rules:

```lex
.|\n    ECHO
```

Because of that, the smallest valid scanner description looks like this:

```lex
%%
```

The [definitions](#format-of-the-definitions-section) and [rules 
section](#format-of-the-definitions-section) are empty, and the [user 
code section](#format-of-the-user-code-section) is missing in this case.
The generated scanner will therefore copy its entire input to the
output.

## How It Really Works

The above description comes close to the actual behavior but is actually
not true.  Take the following scanner definition as an example:

```lex
%%
[ a-zA-Z]+                     ECHO;
.|\n                              /* discard */
```

Kalex will translate that into a regular expression which will roughly look
like this in Perl:

```perl
qr{\G([^a-zA-Z0-9 ])(?:{$r = 0})|(.|\n)(?:{$r = 1})|(.|\n)(?:{$r = 2})}
```

It creates a long regular expression with alternations, where each 
alternation corresponds to a rule.  After each alternation, it inserts
a little code snippet that is needed for finding out which rule had
matched.  The code is actually not `$r = N` but rather reads 
`$self->{__yymatch} = [ ... ]` where the elipsis stands for data that
helps doing the rest of the job faster.

If you are using [start conditions](#start-conditions), then such a
regular expression is generated for each of them.  They differ in the
combination of active rules for each start condition.

### Captures

You are allowed to capture submatches with parentheses.  Kalex keeps
track of them so that it can provide you the submatches in the variables
`$_[1]`, `$_[2]`, ..., no matter at which position in the input file
the rule appears.

Caveat: The relatively new `/n` modifier which prevents the grouping
metacharacters `()` from matching is currently ignored.  Do not use it!

### Backreferences

Likewise, backreferences (`\1, \2, ... \n`) are also modified in the
regular expression before it is being compiled to point at the correct
submatch.

## Performance Considerations

Optimizing your scanner usually boils down to two simple rules:

1) Rules that often match should preferably appear early in the input.
2) Longer matching regexes are faster than regexes with short matches.

Rule 1 is often hard to follow and can introduce bugs if you are not 
careful enough.

Example for rule 2: You want to create a scanner that strips off all
HTML markups (we ignore HTML comments for simplicity):

Bad:

```lex
%s MARKUP
%%
<               YYBEGIN('MARKUP')
>               YYBEGIN('INITIAL')
<MARKUP>.|\n    /* discard */
.|\n            ECHO;
```

Good:

```lex
%%
\<.*?>         /* discard */
[^<]+          ECHO;
```

That does exactly the same as before but it matches the larget possible
chunks of data.  That means it does less matches, and the action code
gets executed less often.  The "bad" example above instead matches 
one character at a time.

The last rule of the "bad" example is not needed because it is identical
to the default rule.

## Alternations

Keep in mind that every rule in the input becomes an alternation in the
generated regular expressions:

```lex
%%
([-a-zA-Z]+)|([0-9]+)                yyprint(">>>$yytext<<<");
```

An equivalent but probably more readable description would look like this:

```lex
%%
[-a-zA-Z]+                           |
[0-9]+                               yyprint(">>>$yytext<<<");
```

Not that the first form is a real challenge for an average Perl hacker but
the second one is simply clearer.  The action `|` for the first rule 
means "same as the following".

# ACTIONS

Each rule can have an *action* which is arbitrary Perl code immediately
following the [pattern](#patterns).  Remember that whitespace outside
of character classes (`[...]`) in patterns has to be properly escaped.

If the action is empty, the matched text will be discarded.  The following
example will delete all occurences of the word bug from the input:

```lex
%%
bugs?
```

All other input is passed through because of the default rule.

The following example from the flex manual compresses multiple spaces and
tabs into a single space character, and throws away whitespace found at 
the end of a line:

```lex
%%
[ \t]+$       /* ignore this token */
[ \t]+        print ' ';
```

You do not need a trailing semi-colon in the action as it is automatically
added but it also doesn't hurt.

If the action code spans multiple lines, you have to enclose it in
curly braces `{ ... }`.  The form `%{ ... %}` is also allowed:

```lex
%%
[-+]?[0-9]+.[0-9]+  {
                        print "float: $yytext\n";
                    }
[-+]?[0-9] /* alternative: */ %{
                                  print "integer: $yytext\n";
                              %} /* end of action */
.|\n                # Throw away everything else.
```

Note how you can put C-Style comments before and after actions.
Perl style comments are treated as code and are copied verbatim
to the scanner.

An action consisting solely of a pipe symbol means "execute the
action for the following rule":

```lex
[-a-zA-Z]+        /* fall through */ |
                                       /* fall through */
[0-9]+\.[0-9]+                       |
[0-9]+                               yyprint(">>>$yytext<<<");
```

Note that you cannot put comments after the pipe symbol because it cannot
be distinguished from legitimate Perl code.  Comments before the pipe
symbol or above the line are okay.

Actions can contain arbitrary Perl code including `return` statements to
return a value to whatever routine called `yylex()`. Each time `yylex()`
is called it continues processing tokens from where it last left o  until 
it either reaches the end of input or executes a `return`.

A couple of functions/methods are defined by the scanner:

## ECHO

Use `$_[0]->ECHO()` in a [reentrant scanner](#reentrant-scanners).

`ECHO` copies `$yytext` to the scanner's output.

## YYBEGIN

Use `$_[0]->YYBEGIN()` in a [reentrant scanner](#reentrant-scanner).

This method is the equivalent of `BEGIN` for flex scanners.  It 
has been renamed to `YYBEGIN` for kalex because `BEGIN` is a reserved
word in Perl.

`YYBEGIN('FOOBAR')` puts the scanner into the start condition `FOOBAR`
and replaces the current start condition stack with `(FOOBAR)`.

The argument to `YYBEGIN` is a string!  Calling it with an undeclared
start condition name will cause a run-time error.

The start condition `0` is the same as `'INITIAL'`.

## YYPUSH

Use `$_[0]->YYPUSH()` in a [reentrant scanner](#reentrant-scanner).

`YYPUSH('FOOBAR')` puts the scanner into the start condition `FOOBAR`
and pushes `FOOBAR` onto the start condition stack.  You can fall
back to the previous start condition with [`YYPOP`](#yypop).

The argument to `YYPUSH` is a string!  Calling it with an undeclared
start condition name will cause a run-time error.

## YYPOP

Use `$_[0]->YYPOP()` in a [reentrant scanner](#reentrant-scanner).

`YYPOP` will remove the last pushed start condition from the start
condition stack and put the scanner back into the condition it was
before the last call to [`YYPUSH`](#yypush).

Calling `YYPOP()` if the start condition stack has only one element,
will cause a run-time error.

## REJECT

Use `$_[0]->REJECT()` in a [reentrant scanner](#reentrant-scanner).

`REJECT` pushes back the last matched text onto the input and matches
again, but skipping the rule that matched last.  So to say, it
picks the second best rule.

Example from the flex documentation:

```lex
    my $word_count = 0
%%
frob        special(); REJECT;
[^ \t\n]    ++$word_count;
```

This scanner calls the function `special()` whenever a word starts with
"frob".  The call to `REJECT` ensures that it is also counted as a
word.

Calling `REJECT` more than once in one action is an error and leads to an
undefined scanner behavior.  However, multiple uses of `REJECT` in
different rules are allowed, and `REJECT` will then skip the current
rule for the next match, and all rules rejected immediately before.  See
this example from the flex documentation:

```lex
%%
abcd         |
abc          |
ab           |
a            ECHO; REJECT;
.|\n         /* eat up any unmatched character */
%%
```
This scanner prints out "abcdabcaba" for all occurences of "abcd" in the
output.  It first matches "abcd", prints it out, and then repeats the
matching but this time with rule 1 omitted.  The second best rule is then
for "abc", and the same happens.  The next best rules are then "ab", and
"a", until the fifth time only the last rule matches that discards the
input and implicitely resets the rejected rule set to empty, so that the
next occurrence of "abcd" will start the procedure over.

Using `REJECT` in flex scanners is somewhat frowned upon because it slows
down the entire scanner.  Kalex scanners work differently and you suffer
from only a mostly negligible performance penalty.

# FREQUENTLY ASKED QUESTIONS

## Quantifier Follows Nothing In Regex

The exact error message is mostly something like:

```
Quantifier follows nothing in regex; marked by <-- HERE in m/* <-- HERE ...
```

Most probably you have used a C style comment inside Perl code, for
example:

```lex
[^ \t]+                   yyprint " "; /* collapse whitespace */
```

That looks correct but Kalex has no (reliable) way of finding out that the
Perl code ends after the semi-colon.  If you want to place a comment after
an action, you have several choices:

```lex
[^ \t]+                   { yyprint " "; } /* collapse whitespace */
[^ \t]+                   %{ yyprint " "; %} /* collapse whitespace */
[^ \t]+                   yyprint " "; # collapse whitespace
```
All of them work.  In brief: Either enclose the Perl code in balanced
braces, or use a Perl comment.

## Unknown regexp modifier "/P" at

It is usually *reported* before [Quantifier Follows Nothing in
Regex](#quantifier-follows-nothing-in-regex) but actually appears
after it.  And it has the same reason.  You are using C-style comments
after one-line actions, see [above](#quantifier-follows-nothing-in-regex).

If you look into the generated source file, you understand the error
message.  It may look like this:

```perl
#line 6 "test.l"
YYRULE0: ECHO    /* some illegal comment; next;

#line 345 "lib/Path/To/Scanner.pm"
YYRULE3: $self->ECHO;; next;
```

The misplaced comment is misinterpreted as a pattern match, and that match
often ends at path references in the source file.

# DIFFERENCES TO FLEX

## Functions and Variables

The following table gives an overview of various functions and variables
in flex and kalex.

<table>
  <thead>
    <tr>
      <th rowspan="2">flex</th>
      <th colspan="2">kalex</th>
    </tr>
    <tr>
      <th>non-reentrant</th>
      <th>reentrant</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>BEGIN</code></td>
      <td><code>YYBEGIN</code></td>
      <td><code>$_[0]->YYBEGIN</code></td>
    </tr>
    <tr>
      <td><code>ECHO</code></td>
      <td><code>ECHO</code></td>
      <td><code>$_[0]->ECHO</code></td>
    </tr>
    <tr>
      <td><code>REJECT</code></td>
      <td><code>REJECT</code></td>
      <td><code>$_[0]->REJECT</code></td>
    </tr>
    <tr>
      <td>-</td>
      <td><code>YYPUSH()</code></td>
      <td><code>$_[0]->YYPUSH()</code></td>
    </tr>
    <tr>
      <td><code>yyleng</code></td>
      <td>-</td>
      <td>-</td>
    </tr>
    <tr>
      <td><code>yylex()</code></td>
      <td><code>yylex()</code></td>
      <td><code>$_[0]->yylex()</code></td>
    </tr>
    <tr>
      <td><code>yymore()</code></td>
      <td><code>yymore()</code></td>
      <td><code>$_[0]->yymore()</code></td>
    </tr>
    <tr>
      <td><code>yytext</code></td>
      <td><code>$yytext</code></td>
      <td><code>$_[0]->{yytext}</code></td>
    </tr>
  <tbody>
</table>

## No yywrap() By Default

Kalex uses yywrap() in exactly the same manner as flex but it assumes
by default that you want to scan just one input stream and does not
attempt to invoke yywrawp() unless you explicitely specify it with

```lex
%option yywrap
```

That avoids the necessity to add `%option noyywrap` to your input
files for the normal use case.

## BEGIN is YYBEGIN

Because `BEGIN` is a compile phase keyword in Perl, it is called `YYBEGIN`
resp. `$self->YYBEGIN()` in kalex.

## YYPUSH and YYPOP

Start conditions in kalex can be stacked.

This feature can sometimes provide elegant solutions.  Most of the time it
is a recipe for trouble because it is very easy to get lost.

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

## REJECT is Less Expensive

Using [`REJECT`](#reject) in only one action slows down the whole scanner
with flex, even those rules that do not call `REJECT`.  Using `REJECT`
in kalex rules only has a very small performance penalty, and you pay
the price only once per occurrence.

The price is that all patterns have to be re-compiled, with the rejected
rule, and possibly previously rejected rules omitted.  But the pattern
set for that particular combination of rejected rules is cached so that
the next `REJECT` will be almost for free.

## Code Following REJECT is Allowed

All code following `REJECT` in flex is discarded.  In kalex scanners, you
can call REJECT wherever you want, not just as the last statement of your
action.

Note however that calling REJECT multiple times within one action leads to
an undefined scanner behavior.

# COPYRIGHT

Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
all rights reserved.

# SEE ALSO

kalex(1), perl(1)
