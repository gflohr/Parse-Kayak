START_TAG <
END_TAG   >
%%
${START_TAG}square${END_TAG} ($START_TAG, $END_TAG) = ('\[', '\]'); yyrecompile();
${START_TAG}angle${END_TAG}  ($START_TAG, $END_TAG) = ('<', '>'); yyrecompile();
${START_TAG}(.*?)${END_TAG}  yyprint "$_[1]\n";
.|\n
%%
$yyin = 't/scanners/yyrecompile-tags.in';
$yyout = 't/scanners/yyrecompile-tags.out';
yylex;
