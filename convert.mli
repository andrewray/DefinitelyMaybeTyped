type out = string -> unit

val mangler : unit -> (string -> string)
val ml_name : string -> string

val interfaceDeclaration : out -> Ast.interfaceDeclaration -> unit
val declarationElement : out -> Ast.declarationElement -> unit


