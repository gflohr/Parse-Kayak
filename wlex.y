%%
input_file: definitions_section rules_section user_code_section
          ;

definitions_section: '%%' definitions
                   ;

definitions: definition definitions
           | /* empty */
           ;

definition: name_definition
          | option
          | DEF_CODE
          ;

name_definition: NAME REGEX
               ;

option: OPTION optionlist
      | valued_option
      ;

valued_option: OPTION OPTION_OUTFILE '=' NAME
             ;

rules_section: '%%' rules
             ;

rules: rule rules 
     | /* empty */
     ;

rule: '<' conditions '>' PATTERN action
    | '<' '*' '>' PATTERN action
    | PATTERN code
    | RULES_CODE
    ;

action: ACTION
      | /* empty */
      ;

conditions: IDENT
          | conditions ',' IDENT
          ;

user_code_section: '%%' USER_CODE
                 | /* empty */
                 ;
%%
