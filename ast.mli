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


