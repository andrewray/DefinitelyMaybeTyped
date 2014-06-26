open Ast

type out = string -> unit

module S = Set.Make(String)
module M = Map.Make(String)

let s_of_list l = List.fold_right S.add l S.empty
let list_of_s s = S.fold (fun elt arg -> elt::arg) s []
let list_of_m m = M.fold (fun key value arg -> value::arg) m []

let not_implemented out m = out m
let error = failwith

(**********************************************************************************)
(* keyword syntax between ocaml and javascript *)

let keywords = [
  "and"; "as"; "assert"; "begin"; "class"; "constraint"; "do"; "done"; "downto"; "else"; "end";
  "exception"; "extern"; "external"; "for"; "fun"; "function"; "functor"; "if"; "in"; "include"; 
  "inherit"; "inherit"; "initializer"; "lazy"; "let"; "match"; "method"; "method"; "module"; 
  "mutable"; "new"; "object"; "of"; "open"; "open"; "or"; "private"; "rec"; "sig"; "struct"; "then"; 
  "to"; "try"; "type"; "val"; "val"; "virtual"; "when"; "while"; "with";
]

let is_keyword = 
  let keywords = List.fold_right S.add keywords S.empty in
  fun s -> 
    try S.find s keywords |> ignore; true
    with Not_found -> false

let ml_name name = 
  let trailing name = if String.contains name '_' then name ^ "_" else name in
  if is_keyword name then name ^ "_"
  else if (name.[0] >= 'A' && name.[0] <= 'Z') || (name.[0] = '_')  then
    "_" ^ trailing name
  else
    trailing name

let rec mangler () = 
  let m = ref S.empty in
  let rec find name idx = 
    let name' = name ^ "_" ^ string_of_int idx in
    try S.find name' !m |> ignore; find name (idx+1)
    with _ -> 
      m := S.add name' !m;
      name'
  in
  fun name ->
  try S.find name !m |> ignore; find name 1
  with _ -> 
    m := S.add name !m;
    name

(**********************************************************************************)
(* compilation *)

let merge_interfaces ast =
  
  let top_interfaces, other = 
    List.partition (function `InterfaceDeclaration _ -> true | _ -> false) ast 
  in
  (*
  let top_modules, _ = List.partition 
    (function 
      | `AmbientDeclaration 
        { amb_ambientDeclaration = `AmbientModuleDeclaration _; _ } -> true
      | _ -> false) other
  in
  let module T = Set.Make(struct
    type t = typeReference
    let compare = Pervasives.compare
  end) in
  *)

  let rec merge_interfaces map = function
    | [] -> map
    | h::t -> begin
        match h with
        | `InterfaceDeclaration 
            ({ idf_identifier = id;
               idf_typeParameters = params;
               idf_interfaceExtendsClause = extends;
               idf_objectType = obj } as idf) -> begin
          let map = 
            try
              let e = M.find id map in
              assert (idf.idf_typeParameters = params); (* I believe these must match exactly *)
              let merge_typeReferences a b = 
                (* XXX 7.2 Declaration Merging; 
                          the extends clauses are merged into a single set of base types *)
                if a <> b then failwith "not implemented; merge_typeReferences"
                else a
              in
              M.add id 
                { idf with 
                    (*idf_interfaceExtendsClause = 
                      merge_typeReferences e.idf_interfaceExtendsClause extends;*)
                    idf_objectType = obj @ e.idf_objectType; 
                } map
            with
            | Not_found ->
              M.add id idf map
          in
          merge_interfaces map t
        end
        | _ -> failwith "not an interface declaration in merge interfaces"
    end
  in

  (* interfaces are now out of order. 
   * could make them recursive, or fix this *)
  (*let intf = List.map (fun x -> `InterfaceDeclaration x) 
    (list_of_m (merge_interfaces M.empty top_interfaces)) 
  in*)

  (* get back list of interfaces in the original order *)
  let map = merge_interfaces M.empty top_interfaces in
  let rec to_list map intf = 
    match intf with
    | [] -> []
    | (`InterfaceDeclaration { idf_identifier=name; _ }) :: t -> begin
        try 
          let x = M.find name map in
          let map = M.remove name map in
          (`InterfaceDeclaration x) :: to_list map t
        with Not_found ->
          to_list map t
    end
    | _ -> failwith "not an interface declaration in merge interfaces"
  in
  let intf = to_list map top_interfaces in

  intf @ other

(**********************************************************************************)
(* code generation *)

let type_ out t = 
  let not_implemented s = not_implemented out s in
  match t with
  | `PredefinedType p ->
      (match p with
      | `Any -> out "Ts.any"
      | `Number -> out "Ts.number"
      | `Boolean -> out "Ts.boolean"
      | `String -> out "Ts.string"
      | `Void -> out "Ts.void")
  | `TypeReference _ -> not_implemented "Ts.typeReference"
  | `TypeQuery _ -> not_implemented "Ts.typeQuery"
  | `TypeLiteral _ -> not_implemented "Ts.typeLiteral"

let type_opt out = function
  | None -> out "Ts.any"
  | Some(t) -> type_ out t

let propertySignature out mangle psg = 
  out ("method " ^ mangle (ml_name psg.psg_propertyName) ^ " : ");
  type_opt out psg.psg_typeAnnotation; 
  out " Js.prop\n"

let parameter_type param = 
  match param with
  | `RequiredParameter x -> x.rpr_typeAnnotation
  (* XXX: how are we going to deal with this properly? *)
  | `RequiredParameterSpecialized _ -> Some(`PredefinedType `Any)
  | `OptionalParameter x -> x.opr_typeAnnotation
  | `OptionalParameterInit _ -> error "OptionalParameterInit"
  (* XXX: how are we going to deal with this properly? *)
  | `OptionalParameterSpecialized _ -> Some(`PredefinedType `Any)
  (* : any[] *)
  | `RestParameter _ -> Some(`TypeLiteral (`ArrayType { arr_elementType = `PredefinedType `Any;
                                                        arr_dimensions = 1 }))

let callSignature out csg = 
  (*assert (csg.csg_typeParameters = None);*)
  if csg.csg_parameterList=[] then begin
    out "Ts.void -> "
  end else begin
    List.iter (fun p ->
      let t = parameter_type p in
      type_opt out t;
      out " -> "
    ) csg.csg_parameterList;
  end;
  type_opt out csg.csg_typeAnnotation

let methodSignature out mangle mts = 
  out ("method " ^ mangle (ml_name mts.mts_propertyName) ^ " : ");
  (*out "(";*)
  callSignature out mts.mts_callSignature;
  out " Js.meth\n"

let interfaceDeclaration out idf = 
  let mangle = mangler () in
  let not_implemented = not_implemented out in
  (* assert (idf.idf_typeParameters = None);
     assert (idf.idf_interfaceExtendsClause = None); *)

  out ("(* interfaceDeclaration *)\n");
  out ("class type " ^ ml_name idf.idf_identifier ^ " = object\n");
    
  List.iter (function
    | `PropertySignature psg -> propertySignature out mangle psg
    | `CallSignature _ -> not_implemented "(* CallSignature *)\n"
    | `ConstructSignature _ -> not_implemented "(* ConstructSignature *)\n"
    | `IndexSignature _ -> not_implemented "(* IndexSignature *)\n"
    | `MethodSignature mts -> methodSignature out mangle mts
  ) idf.idf_objectType;

  out ("end\n")

let ambientVariableDeclaration out avd =
  out ("(* ambientVariableDeclaration *)\n");
  out ("let (" ^ ml_name avd.avd_identifier ^ " : ");
  type_opt out avd.avd_typeAnnotation;
  out ") ";
  out "= Js.Unsafe.variable ";
  out ("\"" ^ avd.avd_identifier ^ "\"");
  out "\n"

let ambientFunctionDeclaration out afn = 
  out ("(* ambientFunctionDeclaration *)\n");
  out ("let " ^ ml_name afn.afn_identifier ^ " : ");
  callSignature out afn.afn_callSignature;
  out " = fun ";
  let len = List.length afn.afn_callSignature.csg_parameterList in
  if len=0 then begin
      out "() "
  end else begin
    for i=0 to len - 1 do
      out ("p" ^ string_of_int i ^ " ");
    done
  end;
  out "-> Js.Unsafe.fun_call ";
  out ("(Js.Unsafe.variable \"" ^ afn.afn_identifier ^ "\") ");
  out "[| ";
  for i=0 to len - 1 do
    out ("Js.Unsafe.inject p" ^ string_of_int i ^ "; ");
  done;
  out " |]\n"

let ambientDeclaration out amb = 
  let not_implemented = not_implemented out in
  match amb with
  | `AmbientVariableDeclaration (_,avd) -> ambientVariableDeclaration out avd
  | `AmbientFunctionDeclaration (_,afn) -> ambientFunctionDeclaration out afn
  | `AmbientClassDeclaration _ -> not_implemented "(* AmbientDeclaration *)\n"
  | `AmbientEnumDeclaration _ -> not_implemented "(* AmbientDeclaration *)\n"
  | `AmbientModuleDeclaration _ -> not_implemented "(* AmbientDeclaration *)\n" 
  | `AmbientExternalModuleDeclaration _ -> not_implemented "(* AmbientDeclaration *)\n"

let declarationElement out decl = 
  let not_implemented = not_implemented out in
  match decl with
  | `ExportAssignment name -> not_implemented "(* ExportAssignment *)\n"
  | `InterfaceDeclaration idf -> interfaceDeclaration out idf
  | `ImportDeclaration idl -> not_implemented "(* ImportDeclaration *)\n"
  | `ExternalImportDeclaration eid -> not_implemented "(* ExternalImportDeclaration *)\n"
  | `AmbientDeclaration amb -> ambientDeclaration out amb
  
let convert out ast = 
  let merge = true in
  if merge then
    List.iter (declarationElement out) (merge_interfaces ast)
  else
    List.iter (declarationElement out) ast 

