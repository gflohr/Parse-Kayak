%%
\\              my $c = yyinput; yyprint "\\$c\n";
.|\n
%%
$yyin = 't/scanners/yyinput-backslash.in';
$yyout = 't/scanners/yyinput-backslash.out';
yylex;
