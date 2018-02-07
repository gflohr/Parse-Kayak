%%
#(.*)       unput(' */'); unput($_[1]); unput('/*');
/\*.*?\*/   ECHO;
.           /* discard */
%%
$yyin = 't/scanners/unput-comments.in';
$yyout = 't/scanners/unput-comments.out';
yylex;
