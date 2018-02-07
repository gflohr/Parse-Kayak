%%
a               input;
b               input(3);
c               input('invalid');
d               input(-1);
e               input(0);
%%
$yyin = 't/scanners/yyinput.in';
$yyout = 't/scanners/yyinput.out';
yylex;
