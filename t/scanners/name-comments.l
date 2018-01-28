DIGITS [1-9][0-9]+    /* This comment would be illegal for lex/flex.  */
        my $sum = 0;
%%
${DIGITS}        $sum += $yytext; yyprint "+$yytext = $sum\n";
.|\n
%%
$yyin = 't/scanners/name-comments.in';
$yyout = 't/scanners/name-comments.out';
yylex;
