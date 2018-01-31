%%
    /* above rule */
a                               ECHO;
    /* above rule */
<INITIAL>b                      ECHO;
    /* above rule */
~{c}
    /* above rule */
<INITIAL>~{d}
    # above rule
e                    ECHO;
    # above rule
<INITIAL>f           ECHO;
    # above rule
~{g}                  ECHO; 
    # above rule
<INITIAL>~{h}         ECHO;
i                    /* before action */ ECHO;
<INITIAL>j           /* before action */ ECHO;
~{k}                 /* before action */ ECHO; 
<INITIAL>~{l}        /* before action */ ECHO;
m                    { ECHO } /* after action */
<INITIAL>n           { ECHO } /* after action */
~{o}                 { ECHO } /* acter action */
<INITIAL>~{p}        { ECHO } /* after action */
%%
$yyout = 't/scanners/action-comments.out';
$yyin = 't/scanners/action-comments.in';
yylex;
