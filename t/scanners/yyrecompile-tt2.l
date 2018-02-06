WS [ \t]
NWS [^ \t]
OT \[\% 
CT \%\]
%%
${OT}${WS}*TAGS${WS}+($NWS+)${WS}+($NWS+)${WS}*${CT} {
            $OT = quotemeta $_[1];
            $CT = quotemeta $_[2];
            yyrecompile;
        }
${OT}.*?${CT} /* discard */
%%
$yyin='t/scanners/yyrecompile-tt2.in';
$yyout='t/scanners/yyrecompile-tt2.out';
yylex;
