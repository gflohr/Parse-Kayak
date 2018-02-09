%option yylineno
%option noline
%%
est                     return 1;
Belgae,\naliam          return 2;
appellantur\.\n         return 3;
    /* That will move yypos forward!  */
legibus                  $_[0]->yyless(13); return 4;
.|\n
