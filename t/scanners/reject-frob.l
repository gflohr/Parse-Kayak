%{

my $word_count = 0;

sub special {
   yyprint "special called\n";
}

%}
%%
frob            special; REJECT;
[^ \t\n]+       ++$word_count;
.|\n
%%
$yyout = 't/scanners/reject-frob.out';
$yyin = 't/scanners/reject-frob.in';
yylex;

yyprint "The word count is $word_count.\n";
