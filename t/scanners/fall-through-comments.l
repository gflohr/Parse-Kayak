%%
a(a) /* fall through */ | 
e(e)                    |
i(i)                    |
o(o)                    |
u(u)                    yyprint $_[1]
\n                      ECHO
.                       /* discard */
%%
$yyout = 't/scanners/fall-through-comments.out';
$yyin = 't/scanners/fall-through-comments.in';
yylex
