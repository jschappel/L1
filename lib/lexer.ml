open Core
open Token

exception LexError of string * int

(* Reserved Identifiers *)
let map =
  Map.of_alist_exn
    (module String)
    [
      ("let", LET);
      ("in", IN);
      ("fn", FUN);
      ("if", IF);
      ("then", THEN);
      ("else", ELSE);
      ("true", BOOL true);
      ("and", AND);
      ("or", OR);
      ("not", NOT);
      ("false", BOOL false);
      ("letrec", LETREC);
    ]

let lex_number (txt : char list) (line : int) : string =
  let rec helper txt seen_decimal acc =
    match txt with
    | [] -> acc
    | x :: xs -> (
        match x with
        | '0' .. '9' -> helper xs seen_decimal @@ acc ^ Char.to_string x
        | '.' when equal_bool seen_decimal false ->
            helper xs true @@ acc ^ Char.to_string x
        | '.' -> raise @@ LexError ("Invlid number. To many '.'", line)
        | _ ->
            if String.equal "" acc then
              raise @@ LexError ("Invlid number.", line)
            else acc)
  in
  helper txt false ""

let lex_identifier (txt : char list) : int * tokenType =
  let ident =
    String.of_char_list @@ List.take_while txt ~f:(fun x -> Char.is_alphanum x)
  in
  let len = String.length ident in
  match Map.find map ident with
  | Some keyword -> (len, keyword)
  | None -> (len, IDENTIFIER ident)

let lex_string (txt : char list) : string =
  String.of_char_list
  @@ List.take_while txt ~f:(fun c -> not (Char.equal c '"'))

let lex_minus (txt : char list) (line : int) : tokenType * int =
  match txt with
  | '-' :: y :: xs when Char.is_digit y ->
      let num_str = "-" ^ lex_number (y :: xs) line in
      (NUMBER (float_of_string num_str), String.length num_str)
  | '-' :: _ -> (MINUS, 1)
  | _ -> raise @@ LexError ("Unreachable", line)

let lexProgram prog =
  let rec lexLine txt line =
    match txt with
    | [] -> []
    | x :: xs -> (
        match x with
        | '(' -> Token (LEFT_PAREN, line) :: lexLine xs line
        | ')' -> Token (RIGHT_PAREN, line) :: lexLine xs line
        | '.' -> Token (DOT, line) :: lexLine xs line
        | '*' -> Token (STAR, line) :: lexLine xs line
        | '+' -> Token (PLUS, line) :: lexLine xs line
        | ',' -> Token (COMMA, line) :: lexLine xs line
        | '-' ->
            let tt, size = lex_minus txt line in
            let xs = List.drop txt size in
            Token (tt, line) :: lexLine xs line
        | '/' -> Token (SLASH, line) :: lexLine xs line
        | '=' when equal_option Char.equal (List.hd xs) (Some '>') ->
            Token (ARROW, line) :: lexLine (List.drop xs 1) line
        | '=' when equal_option Char.equal (List.hd xs) (Some '=') ->
            Token (EQ_EQ, line) :: lexLine (List.drop xs 1) line
        | '=' -> Token (EQ, line) :: lexLine xs line
        | '>' when equal_option Char.equal (List.hd xs) (Some '=') ->
            Token (GT_EQ, line) :: lexLine (List.drop xs 1) line
        | '>' -> Token (GT, line) :: lexLine xs line
        | '<' when equal_option Char.equal (List.hd xs) (Some '=') ->
            Token (LT_EQ, line) :: lexLine (List.drop xs 1) line
        | '<' -> Token (LT, line) :: lexLine xs line
        | '!' when equal_option Char.equal (List.hd xs) (Some '=') ->
            Token (NOT_EQ, line) :: lexLine (List.drop xs 1) line
        | '\n' -> lexLine xs @@ (line + 1)
        | '"' ->
            let s = lex_string xs in
            let xs = List.drop xs @@ (1 + String.length s) in
            Token (STRING s, line) :: lexLine xs line
        | ' ' | '\t' -> lexLine xs line
        | '0' .. '9' ->
            let num_str = lex_number txt line in
            let xs = List.drop txt @@ String.length num_str in
            Token (NUMBER (float_of_string num_str), line) :: lexLine xs line
        | 'a' .. 'z' | 'A' .. 'Z' ->
            let len, tt = lex_identifier txt in
            let xs = List.drop txt len in
            Token (tt, line) :: lexLine xs line
        | _ ->
            let msg = Printf.sprintf "Invalid token %c" x in
            raise @@ LexError (msg, line))
  in
  lexLine (String.to_list prog) 1
