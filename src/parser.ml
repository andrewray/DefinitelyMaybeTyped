(*
 * Parse typescript definition files.
 *)

open MParser
open MParser_PCRE

(* utils *)

type ('a,'b) pp = ('a, 'b) MParser.t
type 'a p = ('a, unit) pp

let explode str =
  let len = String.length str in 
  let rec f i = 
    if i < len then str.[i] :: f (i+1)
    else []
  in
  f 0

let implode list = 
  let len = List.length list in
  let str = String.create len in
  let rec f i = function
    | [] -> ()
    | h::t -> str.[i] <- h; f (i+1) t
  in
  f 0 list;
  str
(*
let implode list = 
  let s = Array.of_list list in
  String.init (Array.length s) (fun i -> s.(i))
*)
(* comments and whitespace *)

module Comment = struct
  
  let start = "/*"
  let docstart = "/**"
  let end_ = "*/"
  let line = "//"


  (* documentation comment extractor.
   * we parse them when consuming white space for the 
   * token to which they are associated.  We dump them into
   * a reference and clear them at all other white spcae.
   * The plus side of this uberbodge is we don't need to alter
   * the parser except to store the documentation *)
  let doc : string list ref = ref []
  let doc_push s = doc := implode s :: !doc
  let doc_clear () = doc := []
  let docs () = 
    let s = String.concat "" (List.rev !doc) in
    doc_clear ();
    s

  (* skip white space *)
  let ignore_space s = (space >> return ()) s

  (* XXX: references '///' *)

  (* single line comment *)
  let oneline s =
      (attempt (string line)
    >> skip_many (satisfy ((!=) '\n'))
    >> return ()) s

  (* multiline comment *)
  let rec multiline st =
    (attempt (string start) >> multi) st

  and multi s = 
    (    (attempt (string end_) >> return ())
    <|> (skip_many1 (none_of start) >> multi)
    <|> (any_of start >> multi)
    <?> "end of comment") s

  (* multiline documentation comment *)
  let rec docmultiline st =
    (attempt (string docstart) >> docmulti) st

  and docmulti s = 
    (    (attempt (string end_) >> return ())
    <|> (many1 (none_of start) >>= fun s -> doc_push s; docmulti)
    <|> (any_of start >>= fun c -> doc_push [c];  docmulti)
    <?> "end of doc comment") s

end

module Token = struct

  let bom = char '\xef' >> char '\xbb' >> char '\xbf'

  let whitespace s =
    let open Comment in
    (skip_many (ignore_space <|> (*docmultiline <|>*) multiline <|> oneline <?> "")) s

  let lexeme p = (p >>= fun x -> (whitespace >> return x))

  let escaped_char s =
    (any_of "nrtb\\\"\'" |>>
         (function
            | 'n' -> '\n'
            | 'r' -> '\r'
            | 't' -> '\t'
            | 'b' -> '\b'
            | c   -> c)) s

  let escape_sequence_dec =
    let int_of_dec c =
      (Char.code c) - (Char.code '0') in
    let char_of_digits d2 d1 d0 =
      char_of_int (100 * (int_of_dec d2) + 10 * (int_of_dec d1)
                   + (int_of_dec d0))
    in
      fun s ->
        (digit >>= fun d2 ->
         digit >>= fun d1 ->
         digit >>= fun d0 ->
         try_return3 char_of_digits d2 d1 d0
           "Escape sequence is no valid character code" s) s

  let escape_sequence_hex =
    let int_of_hex c =
      if      '0' <= c && c <= '9' then (Char.code c) - (Char.code '0')
      else if 'a' <= c && c <= 'f' then (Char.code c) - (Char.code 'a') + 10
      else if 'A' <= c && c <= 'F' then (Char.code c) - (Char.code 'A') + 10
      else failwith "MParser.int_of_hex: no hex digit" in
    let char_of_digits h1 h0 =
      char_of_int (16 * (int_of_hex h1) + (int_of_hex h0))
    in
      fun s ->
        (char 'x'  >>
         hex_digit >>= fun h1 ->
         hex_digit >>= fun h0 ->
         try_return2 char_of_digits h1 h0
           "Escape sequence is no valid character code" s) s

  let escape_sequence s =
       (escape_sequence_dec
    <|> escape_sequence_hex) s

  let char_token s =
       ((char '\\' >> (escaped_char <|> escape_sequence))
    <|>  any_char) s

  let string_literal c s =
    (char c >> (many_chars_until char_token (char c))
     <?> "string literal") s


  let ident = lexeme (many1 (letter <|> digit <|> char '_' <|> char '$') |>> implode)
  let string name = lexeme (string name)
  let char name = lexeme (char name)
  let integer = (lexeme (many1 digit)) >>= fun x -> return (int_of_string (implode x))

  let stringLiteral = 
    lexeme
      (attempt (string_literal '"')
      <|>      (string_literal '\''))
      <?> "stringLiteral"


end

module TypeScript = struct

  open Ast

  (* utils *)

  let bool_of_option = function None -> return false | Some(_) -> return true

  (* names *)

  let identifier = Token.ident
  let stringLiteral = Token.lexeme Token.stringLiteral 
  let path = sep_by1 identifier (char '.') (* XXX not allowing spaces between '.'s for now,
                                                  use Token.char otherwise *)


  (* types *)

  let rec typeParameter st = 
    (perform
      tpp_identifier <-- identifier;
      tpp_constraint <-- 
        option 
          (perform
            tmp <-- Token.string "extends";
            (*ident <-- (attempt path) <|> (Token.string "{}" >>= fun s -> return [s]); (* XXX *)*)
            ident <-- type_; (* XXX *)
            return ident);
      return {tpp_identifier; tpp_constraint}) st

  and typeParameters st =
    (perform
      tmp <-- Token.char '<';
      params <-- sep_by1 typeParameter (Token.char ',');
      tmp <-- Token.char '>';
      return params) st

  and predefinedType st = 
    (   attempt (Token.string "any" >> return `Any)
    <|> attempt (Token.string "number" >> return `Number)
    <|> attempt (Token.string "boolean" >> return `Boolean)
    <|> attempt (Token.string "string" >> return `String)
    <|> attempt (Token.string "void" >> return `Void)
    <|> fail "predefinedType") st

  and typeReference st = 
    (perform
      (*trf_typeName <-- (attempt path) <|> (stringLiteral >>= fun s -> return [s]); (* XXX *) *)
      trf_typeName <-- path;
      trf_typeArguments <-- option typeArguments;
      return { trf_typeName; trf_typeArguments }) st

  and typeArguments st = 
    (perform
      tmp <-- Token.char '<';
      args <-- sep_by1 type_ (Token.char ',');
      tmp <-- Token.char '>';
      return args) st

  and typeQuery st = 
    (perform
      tmp <-- Token.string "typeof";
      name <-- path;
      return name) st

  (* this is not how the spec defines arrays (which doesn't work
   * and seems ambiguous).  This is more logical but may be wrong. *)
  and elementType st = (* array element type *)
    (   attempt (predefinedType |>> fun x -> `PredefinedType x)
    <|> attempt (typeQuery |>> fun x -> `TypeQuery x)
    <|> attempt (typeReference |>> fun x -> `TypeReference x)
    <|> attempt (objectType |>> fun x -> `ObjectType x)
    (*<|> attempt (arrayType |>> fun x -> `ArrayType x)*)
    <|> fail "elementType") st

  and arrayType st = 
    (perform 
      arr_elementType <-- elementType; (* recurses indefinitely ... *)
      arr_dimensions <-- 
        many1 (perform
          tmp <-- Token.char '[';
          tmp <-- Token.char ']';
          return ()) |>> List.length;
      return { arr_elementType; arr_dimensions }) st

  and functionType st = 
    (perform
      fnt_typeParameters <-- option typeParameters;
      tmp <-- Token.char '(';
      fnt_parameterList <-- parameterList;
      tmp <-- Token.char ')';
      tmp <-- Token.string "=>";
      fnt_type <-- type_;
      return { fnt_typeParameters; fnt_parameterList; fnt_type }) st

  and constructorType st = 
    (perform
      tmp <-- Token.string "new";
      cnt_typeParameters <-- option typeParameters;
      tmp <-- Token.char '(';
      cnt_parameterList <-- parameterList;
      tmp <-- Token.char ')';
      tmp <-- Token.string "=>";
      cnt_type <-- type_;
      return { cnt_typeParameters; cnt_parameterList; cnt_type }) st

  and typeLiteral st = 
    (   zero
    <|> attempt (arrayType |>> fun x -> `ArrayType x)
    <|> attempt (objectType |>> fun x -> `ObjectType x)
    <|> attempt (functionType |>> fun x -> `FunctionType x)
    <|> attempt (constructorType |>> fun x -> `ConstructorType x)
    <|> fail "typeLiteral") st

  and type_ st = 
    (   zero
    <|> attempt (typeQuery |>> fun x -> `TypeQuery x) 
    <|> attempt (typeLiteral |>> fun x -> `TypeLiteral x) 
    <|> attempt (predefinedType |>> fun t -> `PredefinedType t)
    <|> attempt (typeReference |>> fun t -> `TypeReference t)
    <|> fail "type") st

  and typeAnnotation st = 
    (perform 
      tmp <-- Token.char ':';
      type_ <-- type_;
      return type_) st

  and propertyName = 
    attempt stringLiteral <|> identifier
    (* XXX: identifierName | stringLiteral | numericLiteral *)

  and propertySignature st = 
    (perform
      psg_propertyName <-- propertyName;
      psg_optional <-- option (Token.char '?') >>= bool_of_option;
      psg_typeAnnotation <-- option typeAnnotation;
      return { psg_propertyName; psg_optional; psg_typeAnnotation }) st

  and publicOrPrivate st = 
    (   attempt (Token.string "public" >> return `Public)
    <|>         (Token.string "private" >> return `Private)) st

  and requiredParameter st = 
    (perform
      rpr_publicOrPrivate <-- option publicOrPrivate;
      rpr_identifier <-- identifier;
      rpr_typeAnnotation <-- option typeAnnotation;
      return { rpr_publicOrPrivate; rpr_identifier; rpr_typeAnnotation }) st

  and requiredParameterSpecialized st = 
    (perform
      rps_identifier <-- identifier;
      tmp <-- Token.char ':';
      rps_specializedSignature <-- stringLiteral;
      return { rps_identifier; rps_specializedSignature }) st

  and optionalParameter st = 
    (perform
      opr_publicOrPrivate <-- option publicOrPrivate;
      opr_identifier <-- identifier;
      tmp <-- Token.char '?';
      opr_typeAnnotation <-- option typeAnnotation;
      return { opr_publicOrPrivate; opr_identifier; opr_typeAnnotation }) st

  (* XXX NOT SURE WHAT IS ACTUALLY INTENDED HERE,
   *     see select2.d.ts *)
  and optionalParameterSpecialized st = 
    (perform
      ops_identifier <-- identifier;
      tmp <-- Token.char '?';
      tmp <-- Token.char ':';
      ops_specializedSignature <-- stringLiteral;
      return { ops_identifier; ops_specializedSignature }) st

  and initialiser = fail "initialiser"

  and optionalParameterInit st = 
    (perform
      opi_publicOrPrivate <-- option publicOrPrivate;
      opi_identifier <-- identifier;
      opi_typeAnnotation <-- option typeAnnotation;
      opi_initialiser <-- initialiser; (* XXX *)
      return { opi_publicOrPrivate; opi_identifier; opi_typeAnnotation; opi_initialiser }) st

  and restParameter st = 
    (perform
      tmp <-- Token.string "...";
      rsp_identifier <-- identifier;
      rsp_typeAnnotation <-- option typeAnnotation;
      return { rsp_identifier; rsp_typeAnnotation }) st

  and parameter st = 
    (   zero
    <|> attempt (optionalParameterSpecialized |>> fun t -> `OptionalParameterSpecialized t)
    <|> attempt (requiredParameterSpecialized |>> fun t -> `RequiredParameterSpecialized t)
    <|> attempt (optionalParameter |>> fun t -> `OptionalParameter t)
    <|> attempt (optionalParameterInit |>> fun t -> `OptionalParameterInit t)
    <|> attempt (restParameter |>> fun t -> `RestParameter t)
    <|> attempt (requiredParameter |>> fun t -> `RequiredParameter t)
    <|> fail "parameter") st

  and parameterList st = (sep_by (attempt parameter) (Token.char ',')) st

  and callSignature st = 
    (perform
      csg_typeParameters <-- option typeParameters;
      tmp <-- Token.char '(';
      csg_parameterList <-- parameterList;
      tmp <-- Token.char ')';
      csg_typeAnnotation <-- option typeAnnotation;
      return { csg_typeParameters; csg_parameterList; csg_typeAnnotation }) st

  and constructSignature st = 
    (perform
      tmp <-- Token.string "new";
      cns_typeParameters <-- option typeParameters;
      tmp <-- Token.char '(';
      cns_parameterList <-- parameterList;
      tmp <-- Token.char ')';
      cns_typeAnnotation <-- option typeAnnotation;
      return { cns_typeParameters; cns_parameterList; cns_typeAnnotation }) st

  and stringOrNumber st =
    (   attempt (Token.string "string" >> return `String)
    <|>         (Token.string "number" >> return `Number)) st

  and indexSignature st = 
    (perform
      tmp <-- Token.char '[';
      ids_identifier <-- identifier;
      tmp <-- Token.char ':';
      ids_stringOrNumber <-- stringOrNumber;
      tmp <-- Token.char ']';
      ids_typeAnnotation <-- typeAnnotation;
      return { ids_identifier; ids_stringOrNumber; ids_typeAnnotation }) st

  and methodSignature st = 
    (perform
      mts_propertyName <-- propertyName;
      mts_optional <-- (option (Token.char '?')) >>= bool_of_option;
      mts_callSignature <-- callSignature;
      return { mts_propertyName; mts_optional; mts_callSignature }) st

  and typeMember st =
    (   zero
    <|> attempt (constructSignature |>> fun s -> `ConstructSignature s)
    <|> attempt (methodSignature |>> fun s -> `MethodSignature s)
    <|> attempt (callSignature |>> fun s -> `CallSignature s)
    <|> attempt (indexSignature |>> fun s -> `IndexSignature s)
    <|> attempt (propertySignature |>> fun s -> `PropertySignature s)
    <|> fail "typeMember") st

  (* typeMember; typeMember; ....; typeMember[;] *)
  (*and typeMemberList st = 
    let t = 
      attempt (perform
        t <-- typeMember;
        tmp <-- Token.char ';';
        return t)
    in
    (many t >>= (fun t ->
      (   attempt (typeMember >>= fun t' -> return (t@[t'])))
      <|> (return t))) st
  *)

  and typeMemberList st = 
    many (attempt (perform
      t <-- typeMember;
      tmp <-- option (Token.char ';');
      return t)) st

  and objectType st = 
    (perform
      tmp <-- Token.char '{';
      objectType <-- typeMemberList;
      (*tmp <-- option (Token.char ';');*)
      tmp <-- Token.char '}';
      return objectType) st

  (* top level elements *)

  and classOrInterfaceTypeList st = (sep_by1 typeReference (Token.char ',')) st

  and interfaceExtendsClause st = 
    (perform
      tmp <-- Token.string "extends";
      classOrInterfaceTypeList <-- classOrInterfaceTypeList;
      return classOrInterfaceTypeList) st

  let exportAssignment = 
    perform
      tmp <-- Token.string "export";
      tmp <-- Token.char '=';
      identifier <-- identifier;
      tmp <-- option (Token.char ';');
      return identifier

  let interfaceDeclaration st = 
    (perform
      tmp <-- option (Token.string "export"); (* XXX LeapMotion.d.ts; this shouldn't be needed *)
      tmp <-- Token.string "interface";
      idf_identifier <-- identifier;
      idf_typeParameters <-- option typeParameters;
      idf_interfaceExtendsClause <-- option interfaceExtendsClause;
      idf_objectType <-- objectType;
      return 
          { idf_identifier; idf_typeParameters; idf_interfaceExtendsClause; 
            idf_objectType }) st
  
  let importDeclaration st = 
    (perform
      tmp <-- option (Token.string "export"); (* XXX ??? *)
      tmp <-- Token.string "import";
      idl_identifier <-- identifier;
      tmp <-- Token.char '=';
      idl_entityName <-- path;
      tmp <-- option (Token.char ';');
      return { idl_identifier; idl_entityName }) st
  
  let externalImportDeclaration = 
    perform
      eid_export <-- option (Token.string "export") >>= bool_of_option;
      tmp <-- Token.string "import";
      eid_identifier <-- identifier;
      tmp <-- Token.char '=';
      tmp <-- Token.string "require";
      tmp <-- Token.char '(';
      eid_stringLiteral <-- stringLiteral;
      tmp <-- Token.char ')';
      tmp <-- Token.char ';';
      return { eid_export; eid_identifier; eid_stringLiteral }
  
  let ambientVariableDeclaration = 
    perform
      tmp <-- Token.string "var";
      avd_identifier <-- identifier;
      avd_typeAnnotation <-- option typeAnnotation;
      tmp <-- option (Token.char ';');
      return { avd_identifier; avd_typeAnnotation }

  let ambientFunctionDeclaration = 
    perform 
      tmp <-- Token.string "function";
      afn_identifier <-- identifier;
      afn_callSignature <-- callSignature;
      tmp <-- option (Token.char ';');
      return { afn_identifier; afn_callSignature }

  let ambientConstructorDeclaration = 
    perform
      tmp <-- Token.string "constructor";
      tmp <-- Token.char '(';
      params <-- parameterList;
      tmp <-- Token.char ')';
      tmp <-- Token.char ';';
      return params

  let ambientPropertyMemberData data = 
    perform
      apm_publicOrPrivate <-- option publicOrPrivate;
      apm_static <-- option (Token.string "static") >>= bool_of_option;
      apm_propertyName <-- propertyName;
      apm_data <-- data;
      tmp <-- option (Token.char ';');
      return { apm_publicOrPrivate; apm_static; apm_propertyName; apm_data }

  let ambientPropertyMemberDeclaration =
    (   zero
    <|> attempt (ambientPropertyMemberData callSignature |>> 
                    fun d -> `AmbientPropertyMemberDeclarationCallSignature d)
    <|> attempt (ambientPropertyMemberData (option typeAnnotation) |>> 
                    fun d -> `AmbientPropertyMemberDeclarationTypeAnnotation d)
    <|> fail "ambientPropertyMemberDeclaration")

  let ambientClassBodyElement = 
    (   zero
    <|> attempt (ambientConstructorDeclaration |>> fun d -> `AmbientConstructorDeclaration d)
    <|> attempt (ambientPropertyMemberDeclaration |>> fun d -> `AmbientPropertyMemberDeclaration d)
    <|> attempt (indexSignature |>> fun d -> `IndexSignature d)
    <|> fail "ambientClassBodyElement")

  let ambientClassDeclaration = 
    perform
      tmp <-- Token.string "class";
      acd_identifier <-- identifier;
      acd_typeParameters <-- option typeParameters;
      acd_extends <-- option
        (perform
          tmp <-- Token.string "extends";
          ct <-- typeReference;
          return ct);
      acd_implements <-- option
        (perform
          tmp <-- Token.string "implements";
          ci <-- classOrInterfaceTypeList;
          return ci);
      tmp <-- Token.char '{';
      acd_classBody <-- many (attempt ambientClassBodyElement);
      tmp <-- Token.char '}';
      return { acd_identifier; acd_typeParameters; acd_extends; 
               acd_implements; acd_classBody }

  let ambientEnumMember = 
    perform 
      aem_propertyName <-- propertyName;
      aem_integerLiteral <-- option
        (perform
          tmp <-- Token.char '=';  
          int <-- Token.integer;
          return int);
      return { aem_propertyName; aem_integerLiteral }

  let ambientEnumDeclaration = 
    perform
      tmp <-- Token.string "enum";
      aed_identifier <-- identifier;
      tmp <-- Token.char '{';
      aed_enumBody <-- many (attempt ((<<) ambientEnumMember (option (Token.char ','))));
      tmp <-- Token.char '}';
      return { aed_identifier; aed_enumBody }

  let rec ambientModuleElements st = (many (attempt ambientModuleElement)) st

  and ambientModuleElement st = 
    (perform
      export <-- option (Token.string "export") >>= bool_of_option;
      res <-- 
        (   zero
        <|> attempt (ambientVariableDeclaration |>> fun a -> `AmbientVariableDeclaration (export,a))
        <|> attempt (ambientFunctionDeclaration |>> fun a -> `AmbientFunctionDeclaration (export,a))
        <|> attempt (ambientClassDeclaration |>> fun a -> `AmbientClassDeclaration (export,a))
        <|> attempt (interfaceDeclaration |>> fun a -> `InterfaceDeclaration (export,a))
        <|> attempt (ambientEnumDeclaration |>> fun a -> `AmbientEnumDeclaration (export,a))
        <|> attempt (ambientModuleDeclaration |>> fun a -> `AmbientModuleDeclaration (export,a))
        <|> attempt (importDeclaration |>> fun a -> `ImportDeclaration (export,a))
        <|> fail "ambientModuleElement");
    return res) st

  and ambientModuleDeclaration st = 
    (perform
      tmp <-- Token.string "module";
      amd_identifierPath <-- path;
      tmp <-- Token.char '{';
      amd_ambientModuleBody <-- ambientModuleElements;
      tmp <-- Token.char '}';
      return { amd_identifierPath; amd_ambientModuleBody }) st

  let ambientExternalModuleElement = 
    (   zero
    <|> attempt (externalImportDeclaration |>> fun a -> `ExternalImportDeclaration a)
    <|> attempt (ambientModuleElement |>> fun a -> `AmbientModuleElement a)
    <|> attempt (exportAssignment |>> fun a -> `ExportAssignment a)
    <|> fail "ambientExternalModuleElement")

  let ambientExternalModuleElements = many (attempt ambientExternalModuleElement)

  let ambientExternalModuleDeclaration st = 
    (perform
      tmp <-- Token.string "module";
      eamd_name <-- stringLiteral;
      tmp <-- Token.char '{';
      eamd_ambientExternalModuleElements <-- ambientExternalModuleElements;
      tmp <-- Token.char '}';
      return { eamd_name; eamd_ambientExternalModuleElements }) st

  let ambientDeclaration export = 
        zero
    <|> attempt (ambientVariableDeclaration |>> fun a -> `AmbientVariableDeclaration (export,a))
    <|> attempt (ambientModuleDeclaration |>> fun a -> `AmbientModuleDeclaration (export,a))
    <|> attempt (ambientFunctionDeclaration |>> fun a -> `AmbientFunctionDeclaration (export,a))
    <|> attempt (ambientClassDeclaration |>> fun a -> `AmbientClassDeclaration (export,a))
    <|> attempt (ambientEnumDeclaration |>> fun a -> `AmbientEnumDeclaration (export,a))
    <|> attempt (ambientExternalModuleDeclaration |>> fun a -> 
        `AmbientExternalModuleDeclaration (export,a))
    <|> fail "ambientDeclaration" 

  let ambientDeclaration = 
    perform
      export <-- option (Token.string "export") >>= bool_of_option;
      tmp <-- Token.string "declare";
      amb <-- 
        zero
        <|> attempt (ambientVariableDeclaration |>> fun a -> `AmbientVariableDeclaration (export,a))
        <|> attempt (ambientModuleDeclaration |>> fun a -> `AmbientModuleDeclaration (export,a))
        <|> attempt (ambientFunctionDeclaration |>> fun a -> `AmbientFunctionDeclaration (export,a))
        <|> attempt (ambientClassDeclaration |>> fun a -> `AmbientClassDeclaration (export,a))
        <|> attempt (ambientEnumDeclaration |>> fun a -> `AmbientEnumDeclaration (export,a))
        <|> attempt (ambientExternalModuleDeclaration |>> fun a -> 
            `AmbientExternalModuleDeclaration (export,a))
        <|> fail "ambientDeclaration" ;
      return amb

  let declarationElement st =
    (   zero 
    <|> attempt (ambientDeclaration |>> fun d -> `AmbientDeclaration d)
    <|> attempt (exportAssignment |>> fun d -> `ExportAssignment d)
    <|> attempt (interfaceDeclaration |>> fun d -> `InterfaceDeclaration d)
    <|> attempt (externalImportDeclaration |>> fun d -> `ExternalImportDeclaration d)
    <|> attempt (importDeclaration |>> fun d -> `ImportDeclaration d)
    <|> fail "declarationElement") st

  let rec declarationElements st = 
    ((attempt declarationElement >>= fun d ->
        declarationElements >>= fun dt ->
          return (d::dt))
    <|> (eof >> return [])) st

  let declarationSourceFile = option Token.bom >> Token.whitespace >> declarationElements

end

(*********************************************************************************)

(*let to_string ast =
  Show.show<Ast.declarationElement list option> ast*)

(* parse a string *)
let sparse p s = 
  let open Printf in
  match parse_string p s () with
  | Success(x) ->  x
  | Failed(x,_) -> printf "Error:\n%s\n" x; failwith "parse error"

(* parse a file *)
let parse ?(verbose=false) filename file = 
  let open Printf in
  match parse_channel TypeScript.declarationSourceFile file () with
  | Success(x) -> Some(x)
  | Failed(x,_) -> begin
      (if verbose then printf "ERROR:\n %s\n" x);
      None
  end

