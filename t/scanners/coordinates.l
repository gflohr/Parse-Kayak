DIGIT [0-9]
CHAR [a-zA-Z]
%%
$CHAR$DIGIT           yyprint "coordinate $^N\n";
.|\n
%%
$yyin = 't/scanners/coordinates.in';
$yyout = 't/scanners/coordinates.out';
yylex;
