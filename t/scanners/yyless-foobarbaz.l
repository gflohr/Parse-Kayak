%%
foobarbaz       ECHO; yyless(3);
[a-z]+          ECHO;
%%
$yyin = 't/scanners/yyless-foobarbaz.in';
$yyout = 't/scanners/yyless-foobarbaz.out';
yylex;
