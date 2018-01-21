/* Copyright (C) 2018 Guido Flohr <guido.flohr@cantanea.com>,
 * all rights reserved.

 * This program is free software. It comes without any warranty, to
 * the extent permitted by applicable law. You can redistribute it
 * and/or modify it under the terms of the Do What the Fuck You Want
 * to Public License, Version 2, as published by Sam Hocevar. See
 *http://www.wtfpl.net/ for more details.
 */

%%
input_file: definitions_section rules_section user_code_section { return 1 }
          ;

definitions_section: definitions
                   ;

definitions: definition definitions
           | /* empty */
           ;

definition: name_definition
          | sc_definition
          | option
          | COMMENT
          | DEF_CODE
              {
                  $_[0]->YYData->{generator}->addDefCode($_[1]);
              }
          | TOP_CODE
              {
                  $_[0]->YYData->{generator}->addTopCode($_[1]);
              }
          ;

name_definition: NAME REGEX
               ;

sc_definition: SC conditions_space NEWLINE
             ;

option: OPTION optionlist
      | valued_option
      ;

valued_option: OPTION OPTION_OUTFILE '=' NAME
             ;

rules_section: SEPARATOR rules
             ;

rules: rule rules 
     | /* empty */
     ;

/* ACTION can be empty.  The lexer takes care of that.  */
rule: '<' conditions_comma '>' regex ACTION
        {
            $_[0]->YYData->{generator}->addRule($_[2], $_[4], $_[5]);
        }
    | '<' '*' '>' regex ACTION
        {
            $_[0]->YYData->{generator}->addRule($_[2], [$_[4]], $_[5]);
        }
    | regex ACTION
        {
            $_[0]->YYData->{generator}->addRule(undef, $_[1], $_[2]);
        }
    | RULES_CODE
    ;

regex: PATTERN            { [$_[1], $_[0]->YYData->{lexer}->yylocation] }
     | regex PATTERN      { $_[1]->[0] .= $_[2]; return $_[1] }
     ;

conditions_comma: IDENT
                    {
                        $_[0]->YYData->{generator}->checkStartCondition($_[1]);
                        return [$_[1]];
                    }
                  | conditions_comma ',' IDENT
                    {
                        $_[0]->YYData->{generator}->checkStartCondition($_[1]);
                        push @{$_[1]}, $_[2];
                        return $_[1];
                    }
                    ;

conditions_space: IDENT
                | conditions_space WS IDENT
                ;

user_code_section: SEPARATOR USER_CODE
                   {
                       $_[0]->YYData->{generator}->setUserCode($_[2]);
                   }
                 | SEPARATOR
                 | /* empty */
                 ;
%%
