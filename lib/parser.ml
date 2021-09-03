open Token
open CoreProgram

exception ParseError of string
let rec parse_expression (tokens: token list): expression =
  let (exp, _) = parse_expression_helper  tokens in exp

and parse_expression_helper = function 
| Token(IF, _)::xs -> parse_if_expr xs
| Token(LET, _)::xs -> parse_let_expr xs
| Token(FUN, _)::xs -> parse_fn_expr xs
| tokens -> parse_or_expr tokens

(* TODO(jschappel): function expr goes here *)
and parse_fn_expr tokens =
  let rec parse_args l acc: (string list * token list) =
    match l with
    | Token(IDENTIFIER(i),_)::Token(COMMA,_)::xs -> parse_args xs @@ acc@[i]
    | Token(IDENTIFIER(i),_)::xs -> (acc@[i], xs)
    | _ -> raise @@ ParseError("Invalid lambda synatx. Expected identifier") in
  let (args, xs) = parse_args tokens [] in
  match xs with
  | Token(EQ, _)::xs -> let (body, xs) = parse_expression_helper xs in (FuncExpr(args, body), xs)
  | _ -> raise @@ ParseError("Invalid lambda synatx. Expected '=' after parameters")


and parse_let_expr tokens =
  let parse_single_let = function
    | Token(IDENTIFIER(i),_)::Token(EQ,_)::xs ->
      let (exp1, xs) = parse_expression_helper xs in ((i, exp1), xs)
    | _ -> raise @@ ParseError("Invalid let synatx. Expected identifier follwoed by '='") in
  let rec loop l a = 
    let (exp, xs) = parse_single_let l in
    let exprs = a @ [exp] in (* *)
    match xs with
    | Token(IN, _)::xs | Token(COMMA, _)::Token(IN, _)::xs -> (* Allow for trailing comma on let exprs *)
      let (body, xs) = parse_expression_helper xs in (LetExpr(exprs, body), xs)
    | Token(COMMA, _)::xs -> loop xs exprs
    | _ ->  raise @@ ParseError("Invalid let synatx. Expected 'in' or ','") in
  loop tokens []

and parse_if_expr (tokens: token list): (expression * token list) = 
  let (cond_expr, xs) = parse_expression_helper tokens in
  match xs with
  | (Token(THEN, _)::xs) ->
    let (then_expr, xs) = parse_expression_helper xs in
    (match xs with
    | (Token(ELSE, _)::xs) -> 
      let (else_expr, xs) = parse_expression_helper xs in
      (IfExpr(cond_expr, then_expr, else_expr), xs)
    | _ -> raise @@ ParseError("Invaid if statement form. Expected keyword: 'else' in form if exp then exp else exp"))
  | _ -> raise @@ ParseError("Invaid if statement form. Expected keyword: 'then' in form if exp then exp else exp")

and parse_or_expr tokens =
  let (exp1, xs) = parse_and_expr tokens in
  let rec loop (l: token list) (acc: expression) = 
    match l with
    | (Token(OR, _)::xs) -> 
      let (exp2, xs) = parse_and_expr xs in                            
      loop xs (BinaryExpr(OR, acc, exp2))
    | _ -> (acc, l) in
  loop xs exp1

and parse_and_expr tokens =
  let (exp1, xs) = parse_equality_expr tokens in
  let rec loop (l: token list) (acc: expression) = 
    match l with
    | (Token(AND, _)::xs) -> 
      let (exp2, xs) = parse_equality_expr xs in                            
      loop xs (BinaryExpr(AND, acc, exp2))
    | _ -> (acc, l) in
  loop xs exp1

(* TODO(jschappel): Conditional goes here *)

and parse_equality_expr tokens =
  let (exp1, xs) = parse_comparison_expr tokens in
  let rec loop (l: token list) (acc: expression) = 
    match l with
    | (Token(op, _)::xs) ->
      (match op with 
      | EQ_EQ | NOT_EQ -> 
        let (exp2, xs) = parse_comparison_expr xs in                            
        loop xs (BinaryExpr(op, acc, exp2))
      | _ -> (acc, l))
    | _ -> (acc, l) in
  loop xs exp1

and parse_comparison_expr tokens =
  let (exp1, xs) = parse_add_sub_expr tokens in
  let rec loop (l: token list) (acc: expression) = 
    match l with
    | (Token(op, _)::xs) ->
      (match op with 
      | GT | GT_EQ | LT | LT_EQ -> 
        let (exp2, xs) = parse_add_sub_expr xs in                            
        loop xs (BinaryExpr(op, acc, exp2))
      | _ -> (acc, l))
    | _ -> (acc, l) in
  loop xs exp1
  
and parse_add_sub_expr tokens =
  let (exp1, xs) = parse_mult_div_expr tokens in
  let rec loop (l: token list) (acc: expression) = 
    match l with
    | (Token(op, _)::xs) when op = PLUS || op = MINUS -> 
      let (exp2, xs) = parse_mult_div_expr xs in                            
      loop xs (BinaryExpr(op, acc, exp2))
    | _ -> (acc, l) in
  loop xs exp1

and parse_mult_div_expr tokens =
  let (exp1, xs) = parse_unary_expr tokens in
  let rec loop (l: token list) (acc: expression) = 
    match l with
    | (Token(op, _)::xs) when op = SLASH || op = STAR -> 
      let (exp2, xs) = parse_unary_expr xs in                            
      loop xs (BinaryExpr(op, acc, exp2))
    | _ -> (acc, l) in
  loop xs exp1

and parse_unary_expr = function
| (Token(op, _)::xs) when op = NOT -> 
  let (expr, xs) = parse_unary_expr xs in
  (UnaryExpr(op, expr), xs)
| t -> parse_literal_exp t

(* TODO(jschappel): Call goes here *)

and parse_literal_exp = function
| Token(NUMBER(num), _)::xs -> (LiteralExpr(Num(num)), xs)
| Token(BOOL(b), _)::xs -> (LiteralExpr(Bool(b)), xs)
| Token(IDENTIFIER(i), _)::xs -> (LiteralExpr(Ident(i)), xs)
| Token(tt, line)::_ -> let open Debug in raise @@ ParseError("Invalid Token supplied at line:" ^ 
                          (Int.to_string line) ^ " .Given: " ^ (tokenType_to_string tt))
| [] -> raise @@ ParseError("Unreachable")