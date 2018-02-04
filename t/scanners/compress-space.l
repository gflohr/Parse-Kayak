%%
[ \t]+$       /* ignore this token */
[ \t]+        yyprint ' ';
%%
$yyout = 't/scanners/compress-space.out';
$yyin = 't/scanners/compress-space.in';
yylex;
