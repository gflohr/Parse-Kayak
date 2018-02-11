%option yylineno
%%
omnis                   return 1;
Belgae,\naliam          return 2;
appellantur\.\n         return 3;
    /* That will move yypos forward!  */
legibus                 $_[0]->yyless(13); return 4;
Gallos                  $_[0]->yyless(2); return 5;
Aquitanis\nGarumna      $_[0]->yyless(4); return 6;
Matrona[ ]et[ ]         $_[0]->yymore; return 7;
Sequana                 return 8;
fortissimi\n            $_[0]->yymore; return 9;
sunt[ ]Belgae           return 10;
propterea[ ]quod        $_[0]->REJECT; return 11;
propterea               return 12;
humanitate              $_[0]->yyinput(10); $_[0]->yyinput(15); return 13;
minimeque               return 14;
mercatores              $_[0]->yyunput("catch\nme"); return 15;
catch\nme               return 16;
commeant                return 17;
.|\n
