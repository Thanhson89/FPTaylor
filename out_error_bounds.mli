(* ========================================================================== *)
(*      FPTaylor: A Tool for Rigorous Estimation of Round-off Errors          *)
(*                                                                            *)
(*      Author: Alexey Solovyev, University of Utah                           *)
(*                                                                            *)
(*      This file is distributed under the terms of the MIT license           *)
(* ========================================================================== *)

(* -------------------------------------------------------------------------- *)
(* C output for the ErrorBounds tool                                          *)
(* -------------------------------------------------------------------------- *)

val generate_error_bounds : Format.formatter -> Task.task -> unit

val generate_data_functions : Format.formatter -> Task.task -> (string * Expr.expr) list -> unit
