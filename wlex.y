%%
input_file: definitions_section rules_section user_code_section
          ;

definitions_section: '%%' definitions
                   ;

definitions: definition definitions
           | /* empty */
           ;

definition: name_definition
          | DEF_CODE
          ;

name_definition: NAME REGEX
               ;

rules_section: '%%' rules
             ;

rules: rule rules 
     | /* empty */
     ;

rule: '<' conditions '>' PATTERN code
    | PATTERN code
    | RULES_CODE
    ;

conditions: IDENT
          | conditions ',' IDENT
          ;

user_code_section: '%%' USER_CODE
                 | /* empty */
                 ;
%%
