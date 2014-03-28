open Ast
open Printf

module type S = sig
  val ast : Ast.declarationElement list option -> unit
end

module Make(Show : sig
   val show : int -> string -> string -> unit
end) = struct

  open Show

  let path = String.concat "."

  let rec typeMember level = 
    let show = show level in
    function
    | `PropertySignature x -> show "prop" x.psg_propertyName
    | `CallSignature x -> show "call" "(...)"
    | `ConstructSignature x -> show "new" "(...)"
    | `IndexSignature x -> show "index" x.ids_identifier
    | `MethodSignature x -> show "method" x.mts_propertyName

  and ambientClassBodyElement level = 
    let show = show level in
    function
    | `AmbientConstructorDeclaration x -> show "constructor" "(...)"
    | `AmbientPropertyMemberDeclaration (`AmbientPropertyMemberDeclarationTypeAnnotation x) -> 
        show "property [type]" x.apm_propertyName 
    | `AmbientPropertyMemberDeclaration (`AmbientPropertyMemberDeclarationCallSignature x) -> 
        show "property [call]" x.apm_propertyName
    | `IndexSignature x -> show "index" x.ids_identifier

  and ambientModuleElement level = 
    let show n t = show level n t in
    function
    | `AmbientVariableDeclaration avd -> show "var" avd.avd_identifier
    | `AmbientFunctionDeclaration afn -> show "function" afn.afn_identifier
    | `AmbientClassDeclaration acd -> 
        show "class" acd.acd_identifier;
        List.iter (ambientClassBodyElement (level+1)) acd.acd_classBody
    | `AmbientEnumDeclaration aed -> show "enum" aed.aed_identifier
    | `AmbientModuleDeclaration amd -> 
        show "module" (path amd.amd_identifierPath);
        List.iter (fun x -> ambientModuleElement (level+1) x.ame_ambientModuleBody)
          amd.amd_ambientModuleBody
    | `InterfaceDeclaration idf -> 
        show "interface" idf.idf_identifier;
        List.iter (typeMember (level+1)) idf.idf_objectType
    | `ImportDeclaration idl -> show "import" idl.idl_identifier

  and ambientExternalModuleElement level = 
    let show = show level in
    function 
    | `AmbientModuleElement x -> 
        ambientModuleElement (level+1) x.ame_ambientModuleBody
    | `ExportAssignment x -> show "export" x
    | `ExternalImportDeclaration x -> show "import" x.eid_identifier

  and ambientDeclaration level = 
    let show = show level in
    function
    | `AmbientVariableDeclaration avd -> show "declare var" avd.avd_identifier
    | `AmbientFunctionDeclaration afn -> show "declare function" afn.afn_identifier
    | `AmbientClassDeclaration acd -> 
        show "declare class" acd.acd_identifier;
        List.iter (ambientClassBodyElement (level+1)) acd.acd_classBody
    | `AmbientEnumDeclaration aed -> show "declare enum" aed.aed_identifier
    | `AmbientModuleDeclaration amd -> 
        show "declare module" (path amd.amd_identifierPath);
        List.iter (fun x -> ambientModuleElement (level+1) x.ame_ambientModuleBody)
          amd.amd_ambientModuleBody
    | `AmbientExternalModuleDeclaration eamd -> 
        show "declare (ext) module" eamd.eamd_name;
        List.iter (ambientExternalModuleElement (level+1)) eamd.eamd_ambientExternalModuleElements

  and ast = function
    | None -> ()
    | Some(ast) ->
      let show = show 0 in
      printf "summary: %i top level elements\n" (List.length ast);
      (* print a summary of top level values *)
      List.iter (function
        | `ExportAssignment name -> show "export" name
        | `InterfaceDeclaration idf -> 
            show "interface" idf.idf_identifier;
            List.iter (typeMember 1) idf.idf_objectType
        | `ImportDeclaration idl -> show "import" idl.idl_identifier
        | `ExternalImportDeclaration eid -> show "import (ext)" eid.eid_identifier
        | `AmbientDeclaration amb -> ambientDeclaration 0 amb.amb_ambientDeclaration)
        ast

end

module Print = Make(struct
  let show level t n = 
    for i=0 to level-1 do printf " " done;
    printf "%s %s\n" t n
end)

