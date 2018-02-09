%option yylineno
%option noline
%%
est                     return 1;
Belgae,\naliam          return 2;
appellantur.\n          return 3;
.|\n
