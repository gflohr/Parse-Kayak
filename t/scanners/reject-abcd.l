%%
abcd         |
abc          |
ab           |
a            ECHO; REJECT;
\n           ECHO;
.            /* eat up any unmatched character */
%%
$yyout = 't/scanners/reject-abcd.out';
$yyin = 't/scanners/reject-abcd.in';
yylex;
