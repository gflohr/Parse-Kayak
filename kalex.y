%%
input_file: definitions_section rules_section user_code_section
          ;

definitions_section: definitions
                   ;

definitions: definition definitions
           | /* empty */
           ;

definition: name_definition
          | sc_definition
          | option
          | DEF_CODE
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
    | '<' '*' '>' regex WS action
    | regex WS action 
    | RULES_CODE
    ;

regex: PATTERN
     | regex PATTERN
     ;

conditions_comma: IDENT
          | conditions_comma ',' IDENT
          ;

conditions_space: IDENT
          | conditions_space WS IDENT
          ;

user_code_section: SEPARATOR USER_CODE
                 | /* empty */
                 ;
%%
