%%
bar             unput(')'); unput($yytext); unput('(');
\(.*?\)         yyprint $yytext;
.               /* discard */
%%
$yyin = 't/scanners/unput-x.in';
$yyout = 't/scanners/unput-x.out';
yylex;
