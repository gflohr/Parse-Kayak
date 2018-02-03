        my $nephews = 0;
%%
Huey            |                        
Dewey           |
Louie           ++$nephews;
.|\n            /* discard */
%%
$yyin = 't/scanners/same-as-next-rule.in';
$yyout = 't/scanners/same-as-next-rule.out';
yylex;
yyprint "$nephews\n";
