%top {
# Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
# all rights reserved.

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What the Fuck You Want
# to Public License, Version 2, as published by Sam Hocevar. See
# http://www.wtfpl.net/ for more details.
}

%option package="Parse::Kalex::LexerBase"
%option strict
%option yylineno
%option yywrap

IDENT     [^\000-\100\133-\136\140\173-\177][^\000-\057\072-\100\133-\136\140\173-\177]*
WS        [ \011\013-\015]
WSNEWLINE [ \011-\015]
NOWS      [^ \011-\015]
OPTION    [-_a-zA-Z0-9]+

%s RULES
%s USER_CODE
%s CONDITION_DECLS
%s NAME
%s OPTION
%s OPTION_VALUE
%s CONDITIONS
%s ACTION
%s POST_ACTION

%x DEF_REGEX
%x DEF_CC
%x CCOMMENT
%x RULES_REGEX
%x REGEX
%x REGEXCC

%{
use constant YYEOF => ('', undef);
%}

%%
<INITIAL>^%%$WS*\n?                     {
        $yyself->yyshrink(2);
        $yyself->YYBEGIN('RULES');

        return SEPARATOR => '%%';
    }
<INITIAL>^(%[sx])$WS+                   {
        $yyself->yyshrink(2);
        $yyself->YYPUSH('CONDITION_DECLS');
        return SC => $_[1];
    }
<INITIAL>^($IDENT)$WS+                  {
        $yyself->yyshrink(length $_[1]);
        $yyself->YYPUSH('DEF_REGEX');
        return NAME => $_[1];
    }
<INITIAL>^%\{                           {
        my $code = eval { $yyself->__readPerl(substr $yyself->{yyinput},
                                                     $yyself->{yypos} - 2) };
        $yyself->__fatalParseError($@) if $@;
        
        # This will adjust the location pointer.  We need two extra characters
        # for the trailing delimiter.
        $yyself->yyinput(2 + length $code);

        return DEF_CODE => $code;
    }
<INITIAL>^\%top$WSNEWLINE*\{            {
        my $code = eval { $yyself->__readPerl(substr $yyself->{yyinput},
                                                     $yyself->{yypos} - 1) };
        $yyself->__fatalParseError($@) if $@;
        
        # This will adjust the location pointer.  We need one extra character
        # for the trailing delimiter.
        $yyself->yyinput(1 + length $code);

        return TOP_CODE => $code;
    }
<INITIAL>^%option$WS+                   {
        $yyself->yyshrink(7);
        $yyself->YYPUSH('OPTION');
        return OPTION => '%option';
    }
<CCOMMENT>/\*((?:.|\n)*?)\*/            {
        $yyself->YYPOP;
        return COMMENT => $yyself->__convertComment($yyself->{yytext});
    }
<CCOMMENT>/\*                           {
        $yyself->__fatalParseError("cannot find comment delimiter '*/'"
                                   . " before end of file");
    }
<DEF_REGEX>[^ \011-\015\\\[]]+          return PATTERN => $yyself->{yytext};
<DEF_REGEX,DEF_CC>\\(.)                 return PATTERN => $_[1];
<DEF_REGEX>\[                           { # Make vim happy: ]
        $yyself->YYPUSH('DEF_CC');
        return PATTERN => '[';
    }
<DEF_REGEX>$WSNEWLINE+                  {
        # FIXME! Do not fall back to INITIAL but to a state, where we may
        # read sequences of (C) comments.
        $yyself->YYPOP;
    }
<DEF_CC>\]                              {
        $yyself->YYPOP;
        return PATTERN => ']';
    }
<DEF_CC>.                               return PATTERN => $yyself->{yytext};
<DEF_CC>\n                              {
        # Trigger a syntax error.
        return NEWLINE => "\n";
    }
<DEF_REGEX>.                            return PATTERN => $yyself->{yytext};

<CONDITION_DECLS>$IDENT                 return IDENT => $yyself->{yytext};
<CONDITION_DECLS>\n                     {
        $yyself->YYPOP;
        return NEWLINE => "\n";
    }
<NAME>                                  {
        # Match everything.
        $yyself->YYPOP;
        my $pattern = $yyself->__readDefRegex;
        return '', '' if !length $pattern;

        # This will adjust the location pointer.
        $yyself->yyinput(length $pattern);

        return REGEX => $pattern;
    }
<OPTION>($OPTION)$WS*                   {
        $yyself->yyshrink(length $_[1]);
        return OPTION_NAME => $_[1];
    }
<OPTION>=                               {
        $yyself->yypush('OPTION_VALUE');
        return '=', '=';
    }
<OPTION>\n                              {
        $yyself->YYPOP;
    }
<OPTION_VALUE>"([^\\"]*(?:\\(?:.|\n)[^\\"]*)*)" {   # make vim happy: "
        $yyself->YYPOP;
        my $value = eval "qq{$_[1]}";
        if ($@) {
            # FIXME! Define how to communicate lexer errors to the parser.
            return '', $_[1];
        }
        return OPTION_VALUE => $value;
    }
<OPTION_VALUE>'([^\\']*(?:\\(?:[\\'])[^\\']*)*)' {
        $yyself->YYPOP;
        my $value = eval "q{$_[1]}";
        if ($@) {
            # FIXME! Define how to communicate lexer errors to the parser.
            return '', $_[1];
        }
        return OPTION_VALUE => $value;
    }
<OPTION_VALUE>$NOWS                     {
        $yyself->YYPOP;
        return OPTION_VALUE => $yyself->{yytext};
    }
<RULES>^($WS+)(/\*.*?\*/)$WS*\n         {
        # FIXME! Call yyforward() when implemented!
        $yyself->yyshrink((length $_[1]) + (length $_[2]));
        return RULES_CODE => $yyself->__convertComment($_[2]);
    }
<RULES>^($WS+)(.+)\n                    {
        # FIXME! Call yyforward() when implemented!
        $yyself->yyshrink((length $_[1]) + (length $_[2]));
        return RULES_CODE => $_[2];
    }
<RULES>^%%$WS*\n?                       {
        $yyself->yyshrink(2);
        $yyself->YYBEGIN('USER_CODE'); 

        return SEPARATOR => '%%';
    }
<RULES><                                {
        $yyself->YYPUSH('CONDITIONS');
        return '<', '<';
    }
<RULES>                                 {
        $yyself->YYPUSH('RULES_REGEX');
    }
<RULES>\n
<RULES_REGEX>\~                         {
        my $regex = $yyself->__readRuleRegex(substr $yyself->{yyinput},
                                                    $yyself->{yypos});
        $yyself->YYPUSH('ACTION');
        return MREGEX => $regex;
    }
<RULES_REGEX>                           {
        # So that we fall back to ACTION after the next YYPOP.
        $yyself->YYPUSH('ACTION');
        $yyself->YYPUSH('REGEX');
    }
<REGEX>$WS+                             $yyself->YYPOP;
<REGEX>\n                               {
        $yyself->YYBEGIN('RULES');
        return ACTION => '';
    }
<REGEX>\[\]?                            {
        $yyself->YYPUSH('REGEXCC');
        return PATTERN => $yyself->{yytext};
    }
<REGEX>[^\$\\\[\( \011-\015]+           |
<REGEX>\\[1-9][0-9]*                    |
<REGEX>\$[_a-zA-Z][_a-zA-Z0-9]*         |
<REGEX>\$\{[_a-zA-Z][_a-zA-Z0-9]*\}     |
<REGEX>\\.                              |
<REGEX>\(\??                            |
<REGEX>.                                return PATTERN => $yyself->{yytext};
<REGEXCC>\]                             {
        $yyself->YYPOP;
        return PATTERN => $1;
    }
<REGEXCC>\\.                            |
<REGEXCC>.                              return PATTERN => $yyself->{yytext};
<REGEXCC>\n                             {
        # Syntax error.
        return NEWLINE => "\n";
    }
<ACTION>\n                              {
        # The scanner always needs an action.  Return an empty string.
        $yyself->YYBEGIN('RULES');
        return ACTION => '';
    }
<ACTION>%?\{                            {
        my $code = eval { $yyself->__readPerl(substr $yyself->{yyinput},
                                                     -1 + $yyself->{yypos}) };
        $yyself->__fatalParseError($@) if $@;
        $yyself->YYBEGIN('POST_ACTION');
        return ACTION => $code;
    }
    /* One-liner.  */
<ACTION>(.+)\n                          {
        $yyself->yyshrink(length $_[1]);
        $yyself->YYBEGIN('RULES');
        return ACTION => $_[1];
    }
<POST_ACTION>\n                         $yyself->YYBEGIN('RULES');
<USER_CODE>(?:.|\n)*                    {
        $yyself->YYBEGIN('INITIAL');
        return YYEOF if !length $yyself->{yytext};

        return USER_CODE => $yyself->{yytext};
    }
^($WS+)/\*                              {
        $yyself->yyless(length $_[1]);
        $yyself->YYPUSH('CCOMMENT');
    }
<INITIAL>^((?:$WS+.*\n)+)               return DEF_CODE => $yyself->{yytext};
/\*                                     {
        $yyself->yyless(0);
        $yyself->YYPUSH('CCOMMENT');
    }
\n                                      |
${WS}+                                  /* discard */
.                                       {
        return $_[0]->{yytext}, $_[0]->{yytext};
    }
%%
