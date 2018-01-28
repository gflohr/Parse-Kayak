%s VOWELS                     /* After a vowel was seen.  */
%x CONSONANTS                 /* After a consonant was seen.  */

VOWELS [aeiouAEIOU]
CONSONANTS [bcdfghjklmnpqrstvwxyzBCDFGHIJKLMNPQRSTVWXYZ]
%%
<INITIAL>$VOWELS              YYBEGIN('VOWELS'); ECHO;
<INITIAL>$CONSONANTS          YYBEGIN('CONSONANTS'); ECHO;
<VOWELS>$CONSONANTS           YYBEGIN('CONSONANTS'); yyprint '>'; ECHO;
<CONSONANTS>$VOWELS           YYBEGIN('VOWELS'); yyprint '<'; ECHO;
%%
$yyin = 't/scanners/sc-comments.in';
$yyout = 't/scanners/sc-comments.out';
yylex;
