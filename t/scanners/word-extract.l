%%
([a-zA-Z']+)-[ \t]*\n([a-zA-Z']+)   yyprint lc "$_[1]$_[2]\n";           
[a-zA-Z']+                          yyprint lc "$yytext\n";
.|\n                                /* discard */
%%
$yyout = 't/scanners/word-extract.out';
$yyin = 't/scanners/word-extract.in';
yylex;
