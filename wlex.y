%%
input_file: definitions_section rules_section user_code_section
          ;

definitions_section: '%%' definitions
                   ;

definitions: definition definitions
           | /* empty */
           ;

definition: name_definition
          ;

name_definition: NAME REGEX
               ;

rules_section: '%%' rules
             ;

rules: rule rules 
     | /* empty */
     ;

rule: start_conditions PATTERN code
    | PATTERN code
    ;

start_conditions: '<' conditions '>'
                | /* empty */
                ;

conditions: IDENT
          | conditions IDENT
          ;

user_code_section: '%%' CODE
                 | /* empty */
                 ;
%%
