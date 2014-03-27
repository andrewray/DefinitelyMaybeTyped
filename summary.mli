module type S = sig
  val ast : Ast.declarationElement list option -> unit
end

module Make(Show : sig
   val show : int -> string -> string -> unit
end) : S

module Print : S
