type ('a,'b) pp = ('a, 'b) MParser.t
type 'a p = ('a, unit) pp

val explode : string -> char list
val implode : char list -> string

module Comment : sig
  val oneline : unit p
  val multiline : unit p
  val single : unit p  
end

module Token : sig
  val whitespace : unit p
  val lexeme : 'a p -> 'a p
  val string : string -> string p
  val char : char -> char p
  val integer : int p
end

module TypeScript : sig

  type declarationElement = 
    [ `ExportAssignment of string
    | `InterfaceDeclaration of interfaceDeclaration
    | `ImportDeclaration of importDeclaration
    | `ExternalImportDeclaration of externalImportDeclaration
    | `AmbientDeclaration of ambientDeclarationTop ]
  
  and path = string list

  and importDeclaration = 
    {
      idl_identifier : string;
      idl_entityName : path;
    }

  and interfaceDeclaration =
    {
      idf_identifier : string;
      idf_typeParameters : typeParameters option;
      idf_interfaceExtendsClause : interfaceExtendsClause option;
      idf_objectType : objectType;
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
      amd_ambientModuleBody : ambientModuleElements;
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

  val typeParameter : typeParameter p
  val typeParameters : typeParameters p
  val predefinedType : predefinedType p

  val identifier : string p
  val stringLiteral : string p
  val path : path p

  val typeReference : typeReference p
  val typeArguments : type_ list p
  val typeQuery : path p
  val elementType : elementType p
  val arrayType : arrayType p
  val functionType : functionType p
  val constructorType : constructorType p

  val typeLiteral : typeLiteral p
  val type_ : type_ p
  val typeAnnotation : type_ p

  val propertyName : string p
  val propertySignature : propertySignature p

  val publicOrPrivate : publicOrPrivate p
  val requiredParameter : requiredParameter p
  val requiredParameterSpecialized : requiredParameterSpecialized p
  val optionalParameterSpecialized : optionalParameterSpecialized p
  val optionalParameter : optionalParameter p
  val optionalParameterInit : optionalParameterInit p
  val restParameter : restParameter p

  val parameter : parameter p
  val parameterList : parameterList p

  val callSignature : callSignature p
  val constructSignature : constructSignature p
  val stringOrNumber : stringOrNumber p
  val indexSignature : indexSignature p
  val methodSignature : methodSignature p

  val typeMember : typeMember p
  val typeMemberList : typeMemberList p
  val objectType : objectType p
  val exportAssignment : exportAssignment p
  val classOrInterfaceTypeList : classOrInterfaceTypeList p
  val interfaceExtendsClause : classOrInterfaceTypeList p

  val interfaceDeclaration : interfaceDeclaration p
  val importDeclaration : importDeclaration p
  val externalImportDeclaration : externalImportDeclaration p

  val ambientVariableDeclaration : ambientVariableDeclaration p
  val ambientFunctionDeclaration : ambientFunctionDeclaration p

  val ambientConstructorDeclaration : parameterList p
  val ambientPropertyMemberData : 'a p -> 'a ambientPropertyMemberData p
  val ambientPropertyMemberDeclaration : ambientPropertyMemberDeclaration p
  val ambientClassBodyElement : ambientClassBodyElement p
  val ambientClassDeclaration : ambientClassDeclaration p

  val ambientEnumMember : ambientEnumMember p
  
  val ambientEnumDeclaration : ambientEnumDeclaration p
  
  val ambientExternalModuleDeclaration : ambientExternalModuleDeclaration p

  val ambientModuleElement : ambientModuleElement p
  val ambientModuleElements : ambientModuleElements p
  val ambientModuleElementTop : ambientModuleElementTop p
  val ambientModuleDeclaration : ambientModuleDeclaration p

  val ambientExternalModuleElement : ambientExternalModuleElement p
  val ambientExternalModuleElements : ambientExternalModuleElements p
  val ambientExternalModuleDeclaration : ambientExternalModuleDeclaration p
    
  val ambientDeclaration : ambientDeclaration p
  val ambientDeclarationTop : ambientDeclarationTop p

  val declarationElement : declarationElement p

  val declarationSourceFile : declarationElement list p

end

val sparse : 'a p -> string -> 'a
val parse : ?fail:bool -> string -> in_channel -> bool



