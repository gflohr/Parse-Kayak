    my ($num_lines, $num_chars) = (0, 0);
%%
\n      ++$num_lines; ++$num_chars;
.       ++$num_chars;
%%
$yyin = 't/scanners/wc.in';
$yyout = 't/scanners/wc.out';
yylex;
yyprint "# of lines = $num_lines, # of characters= $num_chars\n";
