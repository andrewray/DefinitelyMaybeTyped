(* write out typescript from ast *)

module Make(O : sig val out : string -> unit end) = struct
  open O
  open Ast

  let notimpl ?msg () = 
    match msg with
    | Some(x) -> out ("// not implemented: " ^ x ^ "\n")
    | None -> out "// not implemented\n"

  let ambientVariableDeclaration (e,v) = notimpl()
  
  let ambientDeclaration e = 
    out "// ambientDeclaration\n";
    match e with
    | `AmbientVariableDeclaration x -> ambientVariableDeclaration x
    | `AmbientFunctionDeclaration (e,x) -> notimpl()
    | `AmbientClassDeclaration (e,x) -> notimpl()
    | `AmbientEnumDeclaration (e,x) -> notimpl()
    | `AmbientModuleDeclaration (e,x) -> notimpl()
    | `AmbientExternalModuleDeclaration (e,x) -> notimpl()

  let declarationElement e = 
    out "// declarationElement\n";
    match e with
    | `ExportAssignment s -> notimpl()
    | `InterfaceDeclaration i -> notimpl()
    | `ImportDeclaration i -> notimpl()
    | `ExternalImportDeclaration i -> notimpl()
    | `AmbientDeclaration i -> notimpl ~msg:"ambientDeclaration" ()

  let print_ast = function
    | None -> out "Empty AST\n"
    | Some(x) ->
        List.iter declarationElement x

end


