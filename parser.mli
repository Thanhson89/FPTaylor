(* ========================================================================== *)
(*      FPTaylor: A Tool for Rigorous Estimation of Round-off Errors          *)
(*                                                                            *)
(*      Author: Alexey Solovyev, University of Utah                           *)
(*                                                                            *)
(*      This file is distributed under the terms of the MIT license           *)
(* ========================================================================== *)

(* -------------------------------------------------------------------------- *)
(* Auxiliary parser functions                                                 *)
(* -------------------------------------------------------------------------- *)

val parse_raw_expr : string -> Input_parser_env.raw_expr

val parse_expr : string -> Expr.expr

val parse_string : string -> Task.task list

val parse_file : string -> Task.task list
