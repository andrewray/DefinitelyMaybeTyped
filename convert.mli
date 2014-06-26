type out = string -> unit

val mangler : unit -> (string -> string)
val ml_name : string -> string

val merge_interfaces : Ast.declarationElement list -> Ast.declarationElement list

val interfaceDeclaration : out -> Ast.interfaceDeclaration -> unit
val declarationElement : out -> Ast.declarationElement -> unit

val convert : out -> Ast.declarationElement list -> unit
