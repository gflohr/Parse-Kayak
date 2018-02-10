%option yylineno
%%
est                     return 1;
Belgae,\naliam          return 2;
appellantur\.\n         return 3;
    /* That will move yypos forward!  */
legibus                 $_[0]->yyless(13); return 4;
Gallos                  $_[0]->yyless(2); return 5;
Aquitanis\nGarumna      $_[0]->yyless(4); return 6;
.|\n
