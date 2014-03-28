/*
 * File which generates all the possible top level elements in a typescript definition file.
 *
 */

// AmbientDeclaration AmbientVariableDeclaration
declare var a_var : number;

// AmbientDeclaration AmbientModuleDeclaration
declare module A_module {

  // AmbientVariableDeclaration
  var a_var : string;

  // AmbientFunctionDeclaration
  function a_function();

  // AmbientClassDeclaration
  class A_class {
  }

  // InterfaceDeclaration
  interface An_interface {}

  // AmbientDeclaration AmbientEnumDeclaration
  enum An_enum {
    A, B, C, D
  }

  // AmbientModuleDeclaration (recursive)
  module A_nested_module {
    var a_var : string;
    function a_function();
    class A_class {}
    interface An_interface {}
    enum An_enum { A, B, C, D }
    module B_nested_module {}
    import A = A_module
  }

  // ImportDeclaration
  import A = A_module

}

// AmbientDeclaration AmbientFunctionDeclaration
declare function a_function();

// AmbientDeclaration AmbientClassDeclaration
declare class A_class {

  // AmbientConstructorDeclaration
  constructor();

  // AmbientPropertyMemberDeclaration AmbientPropertyMemberDeclarationTypeAnnotation
  public a:string;

  // AmbientPropertyMemberDeclaration AmbientPropertyMemberDeclarationCallSignature
  b(c):d;

  // IndexSignature
  [ hello : string ] : string // ';' ??? bug
  [ world : number ] : string // ';' ??? bug
    // XXX somewhere in the parsers the semi-colon is accepted ie in interfaces,
    // hence I have't just added the production to read it.
}

// AmbientDeclaration AmbientEnumDeclaration
declare enum An_enum {
  A, B, C, D
}

// AmbientDeclaration AmbientExternalModuleDeclaration
declare module "An_external_module" {

  // AmbientModuleDeclaration (recursive)
  module A_nested_module {
    var a_var : string;
    function a_function();
    class A_class {}
    interface An_interface {}
    enum An_enum { A, B, C, D }
    module B_nested_module {}
    import A = A_module
  }

  // ExportAssignment
  export = A_module;

  // ExternalImportDeclaration
  import ABC = require ( "An_interface" );

}

// InterfaceDeclaration
interface Another_interface {

  // IndexSignature
  [ hello : string ] : string;
  [ world : number ] : string;

}


// ExportAssignment
export = A_module;

// InterfaceDeclaration
interface An_interface {
  // PropertySignature
  some_property;
  a_property : string;

  // CallSignature
  a_fn() : number;
  some_fn(a,b,c);

  // ConstructSignature
  new();

  // MethodSignature
  ();
  (a:void):number;

}

// ExternalImportDeclaration
import ABC = require ( "An_interface" );

// ImportDeclaration
import A = A_module
import B = A_module.A_nested_module;

