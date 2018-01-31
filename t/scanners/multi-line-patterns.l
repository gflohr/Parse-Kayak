
%x NEXTSC

%%
<INITIAL>~{
    [1-9][0-9]*       # the part before the decimal point
    (?:    
    \.                # the decimal point
    [0-9]+            # the fractional part.
    )?                # the fractional part is optional.
}gsx                  YYBEGIN('NEXTSC'); yyprint "1st float: $yytext\n";
<NEXTSC>~{
    [1-9][0-9]*       # the part before the decimal point
    (?:    
    \.                # the decimal point
    [0-9]+            # the fractional part.
    )?                # the fractional part is optional.
}gsx                  yyprint "next float: $yytext\n";
<*>.|\n
%%
$yyout = 't/scanners/multi-line-patterns.out';
$yyin = 't/scanners/multi-line-patterns.in';
yylex;
