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
<CONDITION_DECLS>$IDENT                 return IDENT => $yyself->{yytext};
<CONDITION_DECLS>\n                     {
        $yyself->YYPOP;
        return NEWLINE => "\n";
    }
<RULES>^%%$WS*\n?                       {
        $yyself->yyshrink(2);
        $yyself->YYBEGIN('USER_CODE'); 

        return SEPARATOR => '%%';
    }
<USER_CODE>(?:.|\n)*                    {
        $yyself->YYBEGIN('INITIAL');
        return YYEOF if !length $yyself->{yytext};

        return USER_CODE => $yyself->{yytext};
    }
${WSNEWLINE}+                           /* discard */
.|\n                                    {
        return $_[0]->{yytext}, $_[0]->{yytext};
    }
%%
