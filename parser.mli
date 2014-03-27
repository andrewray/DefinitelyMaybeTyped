type ('a,'b) pp = ('a, 'b) MParser.t
type 'a p = ('a, unit) pp

val explode : string -> char list
val implode : char list -> string

module Comment : sig
  val oneline : unit p
  val multiline : unit p
end

module Token : sig
  val whitespace : unit p
  val lexeme : 'a p -> 'a p
  val string : string -> string p
  val char : char -> char p
  val integer : int p
end

module TypeScript : sig

  open Ast

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

(*val to_string : Ast.declarationElement list option -> string*)
val sparse : 'a p -> string -> 'a
val parse : ?verbose:bool -> string -> in_channel -> Ast.declarationElement list option

