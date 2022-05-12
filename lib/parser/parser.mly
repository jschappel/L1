%{
  open Ast
%}


%token <float> NUMBER
%token <string> STRING
%token <string> SYMBOL
%token <string> ID
%token LPAREN
%token RPAREN
%token TRUE
%token FALSE
%token DEFINE
%token LAMBDA
%token LET
/* %token LETREC */
%token AND
%token NOT
%token OR
%token LIST
%token VECTOR
%token SET
%token BEGIN
%token IF
%token COND
/* %token ELSE */
%token EOF

%type <Ast.program> program
%start program

%%

program:
  | def* EOF { Program $1 } 
  ;

def: 
  | LPAREN; DEFINE; var=ID; e=exp; RPAREN { Def(var, e) }
  /*| LPAREN; DEFINE; LPAREN; n=ID; p=vars; RPAREN; e=exp; RPAREN { DefFunc n p e } */
  ;
  
exp:
  | FALSE { BoolExp false }
  | TRUE { BoolExp true }
  | n=NUMBER { NumExp n }
  | s=SYMBOL { SymExp s }
  | s=STRING { StrExp s }
  | i=ID { VarExp i }
  | LPAREN; IF; e1=exp; e2=exp; e3=exp; RPAREN { IfExp(e1, e2, e3) }
  | LPAREN; COND; brs=cond_branches; RPAREN { CondExp brs }
  | LPAREN; LAMBDA; LPAREN; ids=vars; RPAREN body=exp; RPAREN; { LambdaExp(ids, body) }
  | LPAREN; LET; LPAREN; vals=var_exps; RPAREN; body=exp; RPAREN; { LetExp(vals, body) }
  | LPAREN; AND; es=exp* RPAREN { AndExp es }
  | LPAREN; OR; es=exp* RPAREN { OrExp es }
  | LPAREN; NOT; e=exp; RPAREN { NotExp e }
  | LPAREN; f=exp; es=exp*; RPAREN { AppExp(f, es) }
  | LPAREN; VECTOR; es=exp*; RPAREN { VectorExp es }
  | LPAREN; LIST; es=exp*; RPAREN { ListExp es }
  | LPAREN; SET; var=ID; e=exp; RPAREN { SetExp(var, e) }
  | LPAREN; BEGIN; es=exp*; RPAREN { BeginExp es }

  ;

/* parses a list of vars */
vars:
  | (* empty *) { [] }
  | i=ID; rst=vars { i :: rst }
  ;

/* parses all cond branches */
cond_branches: branch = cond_branches_helper { List.rev branch };
cond_branches_helper:
  | (* empty *) { [] }
  | LPAREN; e1=exp; e2=exp; RPAREN; rst=cond_branches_helper { (e1, e2) :: rst }
  ;

var_exps: decs = var_exps_helper { List.rev decs };
var_exps_helper:
  | (* empty *) { [] }
  | LPAREN; id=ID; e=exp; RPAREN; rst=var_exps_helper { (id, e) :: rst }
  ;