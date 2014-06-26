module Make(O : sig val out : string -> unit end) : sig
  val print_ast : Ast.declarationElement list option -> unit
end
