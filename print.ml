(* write out typescript from ast *)

module Make(O : sig val out : string -> unit end) = struct
  open O
  open Ast

  let notimpl ?msg ?(nl=false) () = 
    (match msg with
    | Some(x) -> out ("/* not implemented: " ^ x ^ " */")
    | None -> out "/* not implemented */");
    (if nl then out "\n")

  let optOut ?(s="") ?(e="") f = function None -> () | Some(x) -> (out s; f x; out e)
  let optOutA f o = optOut ~s:"<" ~e:">" f o
  (*let optOutB f o = optOut ~s:"(" ~e:")" f o*)
  let rec sepOutBy s f = function
    | [] -> ()
    | [x] -> f x
    | x::t -> (f x; out s; sepOutBy s f t)

  let rec typeReference r = 
    sepOutBy "." out r.trf_typeName;
    optOutA (sepOutBy "," type_) r.trf_typeArguments

  and elementType = function
    | `PredefinedType p -> predefinedType p
    | `TypeReference r -> typeReference r
    | `TypeQuery q -> typeQuery q
    | `ObjectType o -> objectType o

  and arrayType a = 
    elementType a.arr_elementType;
    for i=0 to a.arr_dimensions-1 do
      out "[]"
    done

  and typeQuery q = (out "typeof "; sepOutBy "." out q)

  and functionType f = 
    optOutA (sepOutBy "," typeParameter) f.fnt_typeParameters;
    out "(";
    sepOutBy "," parameter f.fnt_parameterList;
    out ") => ";
    type_ f.fnt_type

  and constructorType c = 
    out "new ";
    optOutA (sepOutBy "," typeParameter) c.cnt_typeParameters;
    out "(";
    sepOutBy "," parameter c.cnt_parameterList;
    out ") => ";
    type_ c.cnt_type

  and objectType o = 
    out "{\n";
    List.iter (fun t -> typeMember t; out ";\n") o;
    out "}"

  and typeParameter p = 
    out p.tpp_identifier;
    optOut ~s:"extends " type_ p.tpp_constraint

  and constructSignature c = 
    out "new ";
    optOutA (sepOutBy "," typeParameter) c.cns_typeParameters;
    out "(";
    sepOutBy "," parameter c.cns_parameterList;
    out ")";
    optOut ~s:" : " type_ c.cns_typeAnnotation

  and callSignature c = 
    optOutA (sepOutBy "," typeParameter) c.csg_typeParameters;
    out "(";
    sepOutBy "," parameter c.csg_parameterList;
    out ")";
    optOut ~s:" : " type_ c.csg_typeAnnotation

  and publicOrPrivate = function `Public -> out "public " | `Private -> out "private " 

  and requiredParameter p = 
    optOut publicOrPrivate p.rpr_publicOrPrivate; 
    out p.rpr_identifier;
    optOut ~s:" : " type_ p.rpr_typeAnnotation

  and requiredParameterSpecialized p = 
    out p.rps_identifier;
    out " : ";
    out "\"";
    out p.rps_specializedSignature;
    out "\""

  and optionalParameter p = 
    optOut publicOrPrivate p.opr_publicOrPrivate;
    out p.opr_identifier; out "?";
    optOut ~s:" : " type_ p.opr_typeAnnotation

  and optionalParameterSpecialized p = 
    out p.ops_identifier;
    out "? : ";
    out "\"";
    out p.ops_specializedSignature;
    out "\""

  and optionalParameterInit p = notimpl ~msg:"optionalParameterInit???" ()

  and restParameter p = 
    out "...";
    out p.rsp_identifier;
    optOut ~s:" : " type_ p.rsp_typeAnnotation

  and propertySignature p = 
    out p.psg_propertyName;
    (if p.psg_optional then out "?");
    optOut ~s:" : " type_ p.psg_typeAnnotation

  and methodSignature m = 
    out m.mts_propertyName;
    (if m.mts_optional then out "?");
    callSignature m.mts_callSignature

  and indexSignature i = 
    out "[ ";
    out i.ids_identifier;
    out " : ";
    (match i.ids_stringOrNumber with
    | `Number -> out "number"
    | `String -> out "string");
    out " ] : ";
    type_ i.ids_typeAnnotation

  and parameter = function
    | `RequiredParameter p -> requiredParameter p
    | `RequiredParameterSpecialized p -> requiredParameterSpecialized p
    | `OptionalParameter p -> optionalParameter p
    | `OptionalParameterInit p -> optionalParameterInit p
    | `OptionalParameterSpecialized p -> optionalParameterSpecialized p
    | `RestParameter p -> restParameter p

  and typeMember = function
    | `PropertySignature p -> propertySignature p
    | `CallSignature c -> callSignature c
    | `ConstructSignature c -> constructSignature c
    | `IndexSignature i -> indexSignature i
    | `MethodSignature m -> methodSignature m

  and typeLiteral = function
    | `ObjectType o -> objectType o
    | `ArrayType a -> arrayType a
    | `FunctionType f -> functionType f
    | `ConstructorType c -> constructorType c

  and predefinedType = function
    | `Any -> out "any"
    | `Number -> out "number"
    | `Boolean -> out "boolean"
    | `String -> out "string"
    | `Void -> out "void"

  and type_ t = 
    match t with
    | `PredefinedType x -> predefinedType x
    | `TypeReference r -> typeReference r
    | `TypeQuery q -> typeQuery q
    | `TypeLiteral l -> typeLiteral l

  let ambientVariableDeclaration (e,v) = 
    (if e then out "export ");
    out "declare var "; out v.avd_identifier; 
    (match v.avd_typeAnnotation with
    | None -> out " : any"
    | Some(t) -> (out " : "; type_ t));
    out ";\n"
 
  let ambientFunctionDeclaration (e,f) = 
    (if e then out "export ");
    out "declare function "; out f.afn_identifier;
    callSignature f.afn_callSignature;
    out ";\n"

  let ambientPropertyMemberData f d = 
    optOut publicOrPrivate d.apm_publicOrPrivate;
    (if d.apm_static then out "static ");
    out d.apm_propertyName; out " ";
    f d.apm_data

  let ambientConstructorDeclaration d = 
    out "constructor (";
    sepOutBy "," parameter d;
    out ")"

  let ambientClassBodyElement = function
    | `AmbientConstructorDeclaration d -> ambientConstructorDeclaration d
    | `AmbientPropertyMemberDeclaration (`AmbientPropertyMemberDeclarationCallSignature d) -> 
        ambientPropertyMemberData callSignature d 
    | `AmbientPropertyMemberDeclaration (`AmbientPropertyMemberDeclarationTypeAnnotation d) -> 
        ambientPropertyMemberData (optOut ~s:" : " type_) d 
    | `IndexSignature d -> indexSignature d
    
  let ambientClassDeclaration (e,c) = 
    (if e then out "export ");
    out "declare class "; out c.acd_identifier;
    optOutA (sepOutBy "," typeParameter) c.acd_typeParameters;
    optOut ~s:"extends " ~e:" " typeReference c.acd_extends;
    optOut ~s:"implements " (sepOutBy "," typeReference) c.acd_implements;
    out " {\n";
    List.iter (fun e -> ambientClassBodyElement e; out ";\n") c.acd_classBody;
    out "}\n"

  let ambientEnumMember m = 
    out m.aem_propertyName;
    optOut ~s:" = " (fun i -> out (string_of_int i)) m.aem_integerLiteral

  let ambientEnumDeclaration (e,d) = 
    (if e then out "export ");
    out "enum "; out d.aed_identifier; out " {\n";
    sepOutBy ",\n" ambientEnumMember d.aed_enumBody;
    out "\n}\n"

  let exportAssignment s = 
    out "export = ";
    out s;
    out ";\n"

  let importDeclaration d = 
    out "import "; 
    out d.idl_identifier;
    out " = ";
    sepOutBy "." out d.idl_entityName;
    out ";\n"

  let externalImportDeclaration d =
    (if d.eid_export then out "export ");
    out "import "; 
    out d.eid_identifier;
    out " = require(\"";
    out d.eid_stringLiteral;
    out "\");\n"

  let interfaceExtendsClause c =
    optOut ~s:"extends " ~e:" " (sepOutBy "," typeReference) c

  let interfaceDeclaration d = 
    out "interface ";
    out d.idf_identifier; out " ";
    optOut ~s:"<" ~e:"> " (sepOutBy "," typeParameter) d.idf_typeParameters;
    interfaceExtendsClause d.idf_interfaceExtendsClause;
    objectType d.idf_objectType;
    out "\n"

  let rec ambientModuleElement = function
    | `AmbientVariableDeclaration d -> ambientVariableDeclaration d
    | `AmbientFunctionDeclaration d -> ambientFunctionDeclaration d
    | `AmbientClassDeclaration d -> ambientClassDeclaration d
    | `InterfaceDeclaration (_,d) -> interfaceDeclaration d
    | `AmbientEnumDeclaration d -> ambientEnumDeclaration d
    | `AmbientModuleDeclaration (_,d) -> ambientModuleDeclaration d
    | `ImportDeclaration (_,d) -> importDeclaration d (* XXX ??? exports *)

  and ambientModuleDeclaration d = 
    out "module ";
    sepOutBy "." out d.amd_identifierPath;
    out " {\n";
    List.iter ambientModuleElement d.amd_ambientModuleBody;
    out "}\n"

  let ambientExternalModuleElement = function
    | `ExternalImportDeclaration d -> externalImportDeclaration d
    | `AmbientModuleElement d -> ambientModuleElement d
    | `ExportAssignment d -> exportAssignment d

  let ambientExternalModuleDeclaration (e,d) = 
    (if e then out "export ");
    out "declare module \"";
    out d.eamd_name;
    out "\" { \n";
    List.iter ambientExternalModuleElement d.eamd_ambientExternalModuleElements;
    out "\n}\n"

  let ambientDeclaration d = 
    match d with
    | `AmbientVariableDeclaration v -> ambientVariableDeclaration v
    | `AmbientFunctionDeclaration f -> ambientFunctionDeclaration f 
    | `AmbientClassDeclaration c -> ambientClassDeclaration c
    | `AmbientEnumDeclaration e -> ambientEnumDeclaration e
    | `AmbientModuleDeclaration (_,m) -> ambientModuleDeclaration m
    | `AmbientExternalModuleDeclaration m -> ambientExternalModuleDeclaration m

  let declarationElement e = 
    match e with
    | `ExportAssignment s -> exportAssignment s
    | `InterfaceDeclaration d -> interfaceDeclaration d
    | `ImportDeclaration d -> importDeclaration d
    | `ExternalImportDeclaration d -> externalImportDeclaration d
    | `AmbientDeclaration d -> ambientDeclaration d

  let print_ast = function
    | None -> out "Empty AST\n"
    | Some(x) ->
        List.iter declarationElement x

end


