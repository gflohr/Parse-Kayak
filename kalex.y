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
          | options
          | COMMENT
              {
                  $_[0]->YYData->{generator}->addDefCode($_[1]);
              }
          | DEF_CODE
              {
                  $_[0]->YYData->{generator}->addDefCode($_[1]);
              }
          | TOP_CODE
              {
                  $_[0]->YYData->{generator}->addTopCode($_[1]);
              }
          ;

name_definition: NAME {$_[0]->YYData->{generator}->checkName($_[1]) } REGEX
                 {
                     $_[0]->YYData->{generator}->addNameDefinition(
                         $_[1], $_[3]
                     );
                 }
               ;

sc_definition: SC conditions_space NEWLINE
                 {
                     $_[0]->YYData->{generator}->addStartConditions(
                         $_[1], $_[2]
                     );
                 }
             ;

options: OPTION optionlist
           {
               $_[0]->YYData->{generator}->addOptions($_[2]);
           }
       ;

optionlist: option                   { [$_[1]] }
          | option optionlist        { push @{$_[1]}, $_[2] }
          ;

option: OPTION_NAME
            {
                $_[0]->YYData->{generator}->checkOption($_[1]);
            }
      | OPTION_NAME '=' OPTION_VALUE
            {
                $_[0]->YYData->{generator}->checkOption($_[1], $_[3]);
            }
      ;

rules_section: SEPARATOR rules
             ;

rules: rule rules 
     | /* empty */
     ;

/* ACTION can be empty.  The lexer takes care of that.  */
rule: '<' conditions_comma '>' regex rule_comments ACTION rule_comments
        {
            $_[0]->YYData->{generator}->addRule(
                $_[2], $_[4], $_[6], $_[0]->YYData->{lexer}->yylocation
            );
        }
    | '<' '*' '>' regex rule_comments ACTION rule_comments
        {
            $_[0]->YYData->{generator}->addRule(
                  [$_[2]], $_[4], $_[6], $_[0]->YYData->{lexer}->yylocation
            );
        }
    | regex rule_comments ACTION rule_comments
        {
            $_[0]->YYData->{generator}->addRule(
                  [], $_[1], $_[3], $_[0]->YYData->{lexer}->yylocation
            );
        }
    | RULES_CODE
    ;

rule_comments: COMMENT rule_comments
             | /* empty */
             ;

regex: patterns  { $_[1] }
     | MREGEX    { $_[1] }
     ;
     
patterns: PATTERN            { $_[0]->YYData->{generator}->addRegex($_[1]) }
        | patterns PATTERN      { $_[0]->YYData->{generator}->growRegex($_[1], $_[2])}
        ;

conditions_comma: IDENT
                    {
                        $_[0]->YYData->{generator}->checkStartCondition($_[1]);
                        return [$_[1]];
                    }
                  | conditions_comma ',' IDENT
                    {
                        $_[0]->YYData->{generator}->checkStartCondition($_[3]);
                        push @{$_[1]}, $_[3];
                        return $_[1];
                    }
                    ;

conditions_space: IDENT
                    {
                        $_[0]->YYData->{generator}
                                     ->checkStartConditionDeclaration($_[1]);
                        return [$_[1]];
                    }
                | conditions_space IDENT
                    {
                        $_[0]->YYData->{generator}
                                     ->checkStartConditionDeclaration($_[2]);
                        push @{$_[1]}, $_[2];
                        return $_[1];
                    }
                ;

user_code_section: SEPARATOR USER_CODE
                   {
                       $_[0]->YYData->{generator}->setUserCode($_[2]);
                   }
                 | SEPARATOR
                 | /* empty */
                 ;
%%
