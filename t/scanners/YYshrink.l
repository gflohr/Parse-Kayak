%option yylineno
%%
Gallia[ ]est[ ]                 $_[0]->yyshrink(6); return 1;
omnis.*incolunt[ ]              $_[0]->yyshrink(5); return 2;
Belgae,\naliam[ ]               $_[0]->yyshrink(6); return 3;
Aquitani                        return 4;
.|\n                            return $_[0]->{yytext};
