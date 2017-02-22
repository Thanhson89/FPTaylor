(* ========================================================================== *)
(*      FPTaylor: A Tool for Rigorous Estimation of Round-off Errors          *)
(*                                                                            *)
(*      Author: Alexey Solovyev, University of Utah                           *)
(*                                                                            *)
(*      This file is distributed under the terms of the MIT licence           *)
(* ========================================================================== *)

(* -------------------------------------------------------------------------- *)
(* Data structures for loaded variables, definitions, and expressions         *)
(* -------------------------------------------------------------------------- *)

open List
open Expr
open Rounding
open Eval
open Num
open Interval

type raw_expr =
  | Identifier of string
  | Numeral of num
  | Raw_rounding of rnd_info * raw_expr
  | Raw_u_op of string * raw_expr
  | Raw_bin_op of string * raw_expr * raw_expr
  | Raw_gen_op of string * raw_expr list

type raw_formula =
  | Raw_le of raw_expr * raw_expr
  | Raw_lt of raw_expr * raw_expr
  | Raw_eq of raw_expr * raw_expr

type constant_def = {
  const_name : string;
  value : evaluated_const;
}

type var_def = {
  var_type : value_type;
  var_name : string;
  var_index : int;
  lo_bound : evaluated_const;
  hi_bound : evaluated_const;
  uncertainty : evaluated_const;
}

type definition = {
  def_name : string;
  def_expr : expr;
}

type env = {
  constants : (string, constant_def) Hashtbl.t;
  variables : (string, var_def) Hashtbl.t;
  definitions : (string, definition) Hashtbl.t;
  mutable constraints : (string * formula) list;
  mutable expressions : (string * expr) list;
  mutable active_constraints : (string * formula) list;
}

let env = {
  constants = Hashtbl.create 10;
  variables = Hashtbl.create 10;
  definitions = Hashtbl.create 10;
  constraints = [];
  expressions = [];
  active_constraints = [];
}

let reset () =
  let clear = Hashtbl.clear in
  clear env.constants;
  clear env.variables;
  clear env.definitions;
  env.constraints <- [];
  env.expressions <- [];
  env.active_constraints <- []

let find_constant name =
  Hashtbl.find env.constants name

let find_variable name =
  Hashtbl.find env.variables name

let find_definition name =
  Hashtbl.find env.definitions name

let all_variables () =
  Hashtbl.fold (fun _ v s -> v :: s) env.variables []

let all_constraints () =
  env.constraints

let set_active_constraints cs =
  env.active_constraints <- cs 

let get_active_constraints () =
  env.active_constraints

let variable_interval name =
  let v = find_variable name in {
    low = v.lo_bound.interval_v.low;
    high = v.hi_bound.interval_v.high;
  }

let is_same_bounds name =
  let v = find_variable name in
  v.lo_bound.rational_v =/ v.hi_bound.rational_v

let get_low_bound name =
  let v = find_variable name in
  v.lo_bound

let get_high_bound name =
  let v = find_variable name in
  v.hi_bound

let get_var_type name =
  let v = find_variable name in
  v.var_type

(* Applies a given rounding operation recursively *)
let rec apply_raw_rounding rnd expr =
  match expr with
    | Identifier _ -> Raw_rounding (rnd, expr)
    | Numeral _ -> Raw_rounding (rnd, expr)
      (* Do not apply the rounding inside another rounding and
         do not round twice *)
    | Raw_rounding _ -> expr
    | Raw_u_op (op, arg) -> 
      let e1 = apply_raw_rounding rnd arg in
      Raw_rounding (rnd, Raw_u_op (op, e1))
    | Raw_bin_op (op, arg1, arg2) ->
      let e1 = apply_raw_rounding rnd arg1 and
	  e2 = apply_raw_rounding rnd arg2 in
      Raw_rounding (rnd, Raw_bin_op (op, e1, e2))
    | Raw_gen_op (op, args) ->
      let es = map (apply_raw_rounding rnd) args in
      Raw_rounding (rnd, Raw_gen_op (op, es))

let apply_raw_rounding_to_formula rnd f =
  match f with
    | Raw_le (e1, e2) ->
      Raw_le (apply_raw_rounding rnd e1, apply_raw_rounding rnd e2)
    | Raw_lt (e1, e2) ->
      Raw_lt (apply_raw_rounding rnd e1, apply_raw_rounding rnd e2)
    | Raw_eq (e1, e2) ->
      Raw_eq (apply_raw_rounding rnd e1, apply_raw_rounding rnd e2)

(* Builds an expression from a raw expression *)
let rec transform_raw_expr = function
  | Raw_rounding (rnd, arg) ->
    let e1 = transform_raw_expr arg in
    Rounding (rnd, e1)
  | Raw_u_op (str, arg) -> 
    let e1 = transform_raw_expr arg in
    begin
      match str with
	| "-" -> U_op (Op_neg, e1)
	| "abs" -> U_op (Op_abs, e1)
	| "inv" -> U_op (Op_inv, e1)
	| "sqrt" -> U_op (Op_sqrt, e1)
	| "sin" -> U_op (Op_sin, e1)
	| "cos" -> U_op (Op_cos, e1)
	| "tan" -> U_op (Op_tan, e1)
	| "asin" -> U_op (Op_asin, e1)
	| "acos" -> U_op (Op_acos, e1)
	| "atan" -> U_op (Op_atan, e1)
	| "exp" -> U_op (Op_exp, e1)
	| "log" -> U_op (Op_log, e1)
	| "sinh" -> U_op (Op_sinh, e1)
	| "cosh" -> U_op (Op_cosh, e1)
	| "tanh" -> U_op (Op_tanh, e1)
	| "asinh" -> U_op (Op_asinh, e1)
	| "acosh" -> U_op (Op_acosh, e1)
	| "atanh" -> U_op (Op_atanh, e1)
	| "floor_power2" -> U_op (Op_floor_power2, e1)
	| "sym_interval" -> U_op (Op_sym_interval, e1)
	| _ -> failwith ("transform_raw_expr: Unknown unary operation: " ^ str)
    end
  | Raw_bin_op (str, arg1, arg2) -> 
    let e1 = transform_raw_expr arg1 and
	e2 = transform_raw_expr arg2 in
    begin
      match str with
	| "+" -> Bin_op (Op_add, e1, e2)
	| "-" -> Bin_op (Op_sub, e1, e2)
	| "*" -> Bin_op (Op_mul, e1, e2)
	| "/" -> Bin_op (Op_div, e1, e2)
        | "max" -> Bin_op (Op_max, e1, e2)
        | "min" -> Bin_op (Op_min, e1, e2)
	| "^" -> Bin_op (Op_nat_pow, e1, e2)
	| "sub2" -> Bin_op (Op_sub2, e1, e2)
	| _ -> failwith ("transform_raw_expr: Unknown binary operation: " ^ str)
    end
  | Raw_gen_op (str, args) ->
    let es = map transform_raw_expr args in
    begin
      match str with
	| "fma" -> Gen_op (Op_fma, es)
	| _ -> failwith ("transform_raw_expr: Unknown operation: " ^ str)
    end
  | Numeral n ->
    let c = {
      rational_v = n;
      float_v = float_of_num n;
      interval_v = More_num.interval_of_num n;
    } in
    Const c
  | Identifier name ->
    try let def = find_definition name in def.def_expr
    with Not_found ->
      try let var = find_variable name in Var var.var_name
      with Not_found ->
	let c = find_constant name in Const c.value

(* Builds a formula from a raw formula *)
let transform_raw_formula = function
  | Raw_le (r1, r2) -> Le (transform_raw_expr r1, transform_raw_expr r2)
  | Raw_lt (r1, r2) -> Lt (transform_raw_expr r1, transform_raw_expr r2)
  | Raw_eq (r1, r2) -> Eq (transform_raw_expr r1, transform_raw_expr r2)

(* Returns the maximal index of all defined variables *)
let max_var_index () =
  Hashtbl.fold (fun _ v i -> max v.var_index i) env.variables (-1)

(* Adds a constant to the environment *)
let add_constant name raw =
  if Hashtbl.mem env.constants name then
    failwith ("Constant " ^ name ^ " is already defined")
  else
    let expr = transform_raw_expr raw in
    let c = {
      const_name = name;
      value = eval_const_expr expr;
    } in
    Hashtbl.add env.constants name c

(* Adds a variable to the environment *)
let add_variable_with_uncertainty var_type name lo hi uncertainty =
  if Hashtbl.mem env.variables name then
    failwith ("Variable " ^ name ^ " is already defined")
  else
    let lo_expr = transform_raw_expr lo and
	hi_expr = transform_raw_expr hi and
	u_expr = transform_raw_expr uncertainty in
    let lo_bound = eval_const_expr lo_expr and
        hi_bound = eval_const_expr hi_expr in
    if var_type = real_type && lo_bound.rational_v =/ hi_bound.rational_v then
      begin
        Log.report 2 "Variable %s is a constant" name;
        add_constant name lo
      end
    else
      let v = {
          var_type = var_type;
          var_name = name;
          var_index = max_var_index () + 1;
          lo_bound = eval_const_expr lo_expr;
          hi_bound = eval_const_expr hi_expr;
          uncertainty = eval_const_expr u_expr;
        } in
      Hashtbl.add env.variables name v

let add_variable var_type name lo hi =
  add_variable_with_uncertainty var_type name lo hi (Numeral (Int 0))

(* Adds a definition to the environment *)
let add_definition name raw =
  if Hashtbl.mem env.definitions name then
    failwith ("Definition " ^ name ^ " is already defined")
  else
    let expr = transform_raw_expr raw in
    let d = {
      def_name = name;
      def_expr = expr;
    } in
    let _ = Hashtbl.add env.definitions name d in
    expr

(* Adds a constraint to the environment *)
let add_constraint name raw =
  let c = transform_raw_formula raw in
  env.constraints <- env.constraints @ [name, c]

(* Adds a named expression to the environment. Also creates the corresponding definition. *)
let add_expression_with_name name raw =
  let expr = add_definition name raw in
  env.expressions <- env.expressions @ [(name, expr)]

(* Adds an expression to the environment *)
let add_expression raw =
  let name = "Expression " ^ string_of_int (length env.expressions + 1) in
  add_expression_with_name name raw

(* Prints a raw expression *)
let print_raw_expr fmt =
  let p = Format.pp_print_string fmt in
  let rec print = function
    | Identifier name -> p name
    | Numeral n -> p (string_of_num n)
    | Raw_rounding (rnd, e) ->
      p (rounding_to_string rnd); p "("; print e; p ")";
    | Raw_u_op (op, e) -> 
      p op; p "("; print e; p ")";
    | Raw_bin_op (op, e1, e2) ->
      p op; p "("; print e1; p ","; print e2; p ")";
    | Raw_gen_op (op, es) ->
      p op; p "("; Lib.print_list print (fun () -> p ",") es; p ")";
  in
  print

let print_raw_expr_std = print_raw_expr Format.std_formatter
