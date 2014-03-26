(*
 * Parse typescript definition files.
 *)

open MParser

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

(* comments and whitespace *)

module Comment = struct
  
  let start = "/*"
  let end_ = "*/"
  let line = "//"

  let ignore_space s = (space >> return ()) s

  let oneline s =
      (attempt (string line)
    >> skip_many (satisfy ((!=) '\n'))
    >> return ()) s

  let rec multiline st =
    (attempt (string start) >> single) st

  and single s = (
        (attempt (string end_) >> return ())
    <|> (skip_many (none_of start) >> single)
    <|> (any_of start >> single)
    <?> "end of comment") s

end

module Token = struct

  let whitespace s =
    let open Comment in
    (match ("" = line, "" = start) with
        (true,true) -> skip_many (ignore_space <?> "")
      | (true,_)    -> skip_many (ignore_space <|> multiline <?> "")
      | (_,true)    -> skip_many (ignore_space <|> oneline <?> "")
      | _  -> skip_many (ignore_space <|> multiline <|> 
                          oneline <?> "")) s

  let lexeme p = (p >>= fun x -> (whitespace >> return x))

  (*
  let ident = lexeme (
    perform
      first <-- letter <|> char '_';
      rest <-- many (letter <|> digit <|> char '_');
      return (implode (first::rest)))
  *)

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

  (* XXX; no escape sequences *)
(*
  let stringLiteral =
      lexeme
        (attempt (char '"' >> (many_chars_until any_char (char '"')))
        <|>      (char ''' >> (many_chars_until any_char (char ''')))
        <?> "string literal")
*)

  let stringLiteral = 
    lexeme
      (attempt (string_literal '"')
      <|>      (string_literal '\''))
      <?> "stringLiteral"


end

module TypeScript = struct

  type declarationElement = 
    [ `ExportAssignment of string
    | `InterfaceDeclaration of interfaceDeclaration
    | `ImportDeclaration of importDeclaration
    | `ExternalImportDeclaration of externalImportDeclaration
    | `AmbientDeclaration of ambientDeclarationTop ]
  
  and path = string list

  and interfaceDeclaration =
    {
      idf_identifier : string;
      idf_typeParameters : typeParameters option;
      idf_interfaceExtendsClause : interfaceExtendsClause option;
      idf_objectType : objectType;
    }

  and importDeclaration = 
    {
      idl_identifier : string;
      idl_entityName : path;
    }

  and typeParameter = 
    { 
      tpp_identifier : string;
      tpp_constraint : type_ option;
    }

  and typeParameters = typeParameter list

  and interfaceExtendsClause = typeReference list

  and predefinedType = 
    [ `Any | `Number | `Boolean | `String | `Void ]

  and type_ = 
    [ `PredefinedType of predefinedType
    | `TypeReference of typeReference
    | `TypeQuery of path
    | `TypeLiteral of typeLiteral ]

  and typeReference = 
    {
      trf_typeName : path;
      trf_typeArguments : type_ list option;
    }

  and typeMember = 
    [ `PropertySignature of propertySignature
    | `CallSignature of callSignature
    | `ConstructSignature of constructSignature
    | `IndexSignature of indexSignature
    | `MethodSignature of methodSignature ]

  and elementType = 
    [ `PredefinedType of predefinedType
    | `TypeReference of typeReference
    | `TypeQuery of path
    | `ObjectType of objectType
    (*| `ArrayType of arrayType*) ]

  and arrayType = 
    {
      arr_elementType : elementType;
      arr_dimensions : int;
    }

  and typeMemberList = typeMember list

  and objectType = typeMemberList

  and functionType = 
    {
      fnt_typeParameters : typeParameters option;
      fnt_parameterList : parameterList;
      fnt_type : type_;
    }

  and constructorType = 
    {
      cnt_typeParameters : typeParameters option;
      cnt_parameterList : parameterList;
      cnt_type : type_;
    }

  and typeLiteral = 
    [ `ObjectType of objectType
    | `ArrayType of arrayType
    | `FunctionType of functionType
    | `ConstructorType of constructorType ]

  and propertySignature = 
    {
      psg_propertyName : string;
      psg_optional : bool;
      psg_typeAnnotation : type_ option;
    }

  and callSignature =
    {
      csg_typeParameters : typeParameters option;
      csg_parameterList : parameterList;
      csg_typeAnnotation : type_ option;
    }

  and parameter = 
      [ `RequiredParameter of requiredParameter
      | `RequiredParameterSpecialized of requiredParameterSpecialized
      | `OptionalParameter of optionalParameter
      | `OptionalParameterInit of optionalParameterInit
      | `OptionalParameterSpecialized of optionalParameterSpecialized
      | `RestParameter of restParameter ]

  and parameterList = parameter list

  and requiredParameter = 
    {
      rpr_publicOrPrivate : publicOrPrivate option;
      rpr_identifier : string;
      rpr_typeAnnotation : type_ option;
    }

  and requiredParameterSpecialized = 
    {
      rps_identifier : string;
      rps_specializedSignature : string;
    }

  and optionalParameterSpecialized = 
    {
      ops_identifier : string;
      ops_specializedSignature : string;
    }

  and publicOrPrivate = [ `Public | `Private ]

  and optionalParameter = 
    {
      opr_publicOrPrivate : publicOrPrivate option;
      opr_identifier : string;
      opr_typeAnnotation : type_ option;
    }

  and optionalParameterInit = 
    {
      opi_publicOrPrivate : publicOrPrivate option;
      opi_identifier : string;
      opi_typeAnnotation : type_ option;
      opi_initialiser : initialiser;
    }

  and initialiser = unit (* XXX *)

  and exportAssignment = string 

  and classOrInterfaceTypeList = typeReference list

  and restParameter = 
    {
      rsp_identifier : string;
      rsp_typeAnnotation : type_ option;
    }

  and constructSignature = 
    {
      cns_typeParameters : typeParameters option;
      cns_parameterList : parameterList;
      cns_typeAnnotation : type_ option;
    }

  and stringOrNumber = [ `String | `Number ]

  and indexSignature = 
    {
      ids_identifier : string;
      ids_stringOrNumber : stringOrNumber;
      ids_typeAnnotation : type_;
    }

  and methodSignature = 
    {
      mts_propertyName : string; (* XXX *)
      mts_optional : bool;
      mts_callSignature : callSignature;
    }

  and externalImportDeclaration = 
    {
      eid_export : bool;
      eid_identifier : string;
      eid_stringLiteral : string;
    }

  and ambientDeclaration = 
      [ `AmbientVariableDeclaration of ambientVariableDeclaration
      | `AmbientFunctionDeclaration of ambientFunctionDeclaration
      | `AmbientClassDeclaration of ambientClassDeclaration
      | `AmbientEnumDeclaration of ambientEnumDeclaration
      | `AmbientModuleDeclaration of ambientModuleDeclaration
      | `AmbientExternalModuleDeclaration of ambientExternalModuleDeclaration ]

  and ambientDeclarationTop = 
    {
      amb_export : bool;
      amb_ambientDeclaration : ambientDeclaration;
    }

  and ambientVariableDeclaration = 
    {
      avd_identifier : string;
      avd_typeAnnotation : type_ option;
    }
  
  and ambientEnumDeclaration = 
    {
      aed_identifier : string;
      aed_enumBody : ambientEnumMember list;
    }

  and ambientEnumMember = 
    {
      aem_propertyName : string;
      aem_integerLiteral : int option;
    }

  and ambientFunctionDeclaration = 
    {
      afn_identifier : string;
      afn_callSignature : callSignature;
    }

  and ambientClassBodyElement = 
    [ `AmbientConstructorDeclaration of ambientConstructorDeclaration
    | `AmbientPropertyMemberDeclaration of ambientPropertyMemberDeclaration
    | `IndexSignature of indexSignature ]

  and ambientConstructorDeclaration = parameter list

  and ambientPropertyMemberDeclaration = 
    [ `AmbientPropertyMemberDeclarationTypeAnnotation of 
      type_ option ambientPropertyMemberData
    | `AmbientPropertyMemberDeclarationCallSignature of 
      callSignature ambientPropertyMemberData ]

  and 'a ambientPropertyMemberData = (* deriving? *)
    {
      apm_publicOrPrivate : publicOrPrivate option;
      apm_static : bool;
      apm_propertyName : string;
      apm_data : 'a;
    }

  and ambientClassDeclaration = 
    {
      acd_identifier : string;
      acd_typeParameters : typeParameters option;
      acd_extends : typeReference option;
      acd_implements : classOrInterfaceTypeList option;
      acd_classBody : ambientClassBodyElement list;
    }

  and ambientModuleDeclaration = 
    {
      amd_identifierPath : path;
      amd_ambientModuleBody : ambientModuleElementTop list;
    }

  and ambientModuleElement = 
    [ `AmbientVariableDeclaration of ambientVariableDeclaration
    | `AmbientFunctionDeclaration of ambientFunctionDeclaration
    | `AmbientClassDeclaration of ambientClassDeclaration
    | `InterfaceDeclaration of interfaceDeclaration
    | `AmbientEnumDeclaration of ambientEnumDeclaration
    | `AmbientModuleDeclaration of ambientModuleDeclaration
    | `ImportDeclaration of importDeclaration ]

  and ambientModuleElementTop =
    {
      ame_export : bool;
      ame_ambientModuleBody : ambientModuleElement;
    }

  and ambientModuleElements = ambientModuleElementTop list
  
  and ambientExternalModuleDeclaration = 
    {
      eamd_name : string;
      eamd_ambientExternalModuleElements : ambientExternalModuleElements;
    }

  and ambientExternalModuleElement = 
      [ `AmbientModuleElement of ambientModuleElementTop
      | `ExportAssignment of exportAssignment
      | `ExternalImportDeclaration of externalImportDeclaration ]

  and ambientExternalModuleElements = ambientExternalModuleElement list
    (*deriving (Show)*)

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

  let interfaceDeclaration = 
    perform
      tmp <-- option (Token.string "export"); (* XXX LeapMotion.d.ts; this shouldn't be needed *)
      tmp <-- Token.string "interface";
      idf_identifier <-- identifier;
      idf_typeParameters <-- option typeParameters;
      idf_interfaceExtendsClause <-- option interfaceExtendsClause;
      idf_objectType <-- objectType;
      return 
          { idf_identifier; idf_typeParameters; idf_interfaceExtendsClause; idf_objectType }
  
  let importDeclaration = 
    perform
      tmp <-- Token.string "import";
      idl_identifier <-- identifier;
      tmp <-- Token.char '=';
      idl_entityName <-- path;
      return { idl_identifier; idl_entityName }
  
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

  let rec ambientModuleElements st = (many (attempt ambientModuleElementTop)) st

  and ambientModuleElement st = 
    (   zero
    <|> attempt (ambientVariableDeclaration |>> fun a -> `AmbientVariableDeclaration a)
    <|> attempt (ambientFunctionDeclaration |>> fun a -> `AmbientFunctionDeclaration a)
    <|> attempt (ambientClassDeclaration |>> fun a -> `AmbientClassDeclaration a)
    <|> attempt (interfaceDeclaration |>> fun a -> `InterfaceDeclaration a)
    <|> attempt (ambientEnumDeclaration |>> fun a -> `AmbientEnumDeclaration a)
    <|> attempt (ambientModuleDeclaration |>> fun a -> `AmbientModuleDeclaration a)
    <|> attempt (importDeclaration |>> fun a -> `ImportDeclaration a)
    <|> fail "ambientModuleElement") st

  and ambientModuleElementTop st =
    (perform
      ame_export <-- option (Token.string "export") >>= bool_of_option;
      ame_ambientModuleBody <-- ambientModuleElement;
      return { ame_export; ame_ambientModuleBody }) st

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
    <|> attempt (ambientModuleElementTop |>> fun a -> `AmbientModuleElement a)
    <|> attempt (exportAssignment |>> fun a -> `ExportAssignment a)
    <|> fail "ambientExternalModuleElement")

  let ambientExternalModuleElements = many (attempt ambientExternalModuleElement)

  let ambientExternalModuleDeclaration = 
    perform
      tmp <-- Token.string "module";
      eamd_name <-- stringLiteral;
      tmp <-- Token.char '{';
      eamd_ambientExternalModuleElements <-- ambientExternalModuleElements;
      tmp <-- Token.char '}';
      return { eamd_name; eamd_ambientExternalModuleElements }

  let ambientDeclaration = 
        zero
    <|> attempt (ambientVariableDeclaration |>> fun a -> `AmbientVariableDeclaration a)
    <|> attempt (ambientModuleDeclaration |>> fun a -> `AmbientModuleDeclaration a)
    <|> attempt (ambientFunctionDeclaration |>> fun a -> `AmbientFunctionDeclaration a)
    <|> attempt (ambientClassDeclaration |>> fun a -> `AmbientClassDeclaration a)
    <|> attempt (ambientEnumDeclaration |>> fun a -> `AmbientEnumDeclaration a)
    <|> attempt (ambientExternalModuleDeclaration |>> fun a -> `AmbientExternalModuleDeclaration a)
    <|> fail "ambientDeclaration" 

  let ambientDeclarationTop = 
    perform
      amb_export <-- option (Token.string "export") >>= bool_of_option;
      tmp <-- Token.string "declare";
      amb_ambientDeclaration <-- ambientDeclaration;
      return { amb_export; amb_ambientDeclaration }

  let declarationElement =
        zero 
    <|> attempt (ambientDeclarationTop |>> fun d -> `AmbientDeclaration d)
    <|> attempt (exportAssignment |>> fun d -> `ExportAssignment d)
    <|> attempt (interfaceDeclaration |>> fun d -> `InterfaceDeclaration d)
    <|> attempt (externalImportDeclaration |>> fun d -> `ExternalImportDeclaration d)
    <|> attempt (importDeclaration |>> fun d -> `ImportDeclaration d)
    <|> fail "declarationElement"

  let rec declarationElements st = 
    ((attempt declarationElement >>= fun d ->
        declarationElements >>= fun dt ->
          return (d::dt))
    <|> (eof >> return [])) st

  let declarationSourceFile = Token.whitespace >> declarationElements
    (*Token.whitespace >> many1 declarationElement >>= fun r -> eof >> return r*)

end

(*********************************************************************************)

(* parse a string *)
let sparse p s = 
  let open Printf in
  match parse_string p s () with
  | Success(x) ->  x
  | Failed(x,_) -> printf "Error:\n%s\n" x; failwith "parse error"

(* parse a file *)
let parse ?(fail=true) filename file = 
  let open Printf in
  match parse_channel TypeScript.declarationSourceFile file () with
  | Success(x) -> begin
    printf "pass: %s\n%!" filename;
    true
  end
  | Failed(x,_) -> begin
      (if fail then 
        (printf "Error:\n%s\n%!" x; failwith "parse error")
      else
        printf "fail: %s\n%!" filename);
      false
  end

