%s QUOTE
%%
<QUOTE>[^\\"]+     yymore;
<QUOTE>\\(.)       substr $yytext, -2, 2, $_[1]; yymore;
<QUOTE>"           {
                       YYBEGIN('INITIAL');
                       chop $yytext;
                       yyprint "$yytext\n";
                   }
"                  YYBEGIN('QUOTE');
.|\n
%%
$yyout = 't/scanners/yymore-unescape-quotes.out';
$yyin = 't/scanners/yymore-unescape-quotes.in';
yylex;
