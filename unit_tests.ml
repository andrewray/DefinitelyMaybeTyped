open OUnit
open MParser

let parse_string ?(eof=true) p s = 
  if eof then parse_string ((<<) p MParser.eof) s ()
  else parse_string p s ()

let assert_parse_eq ?(eof=true) p str v =
  match parse_string ~eof p str with
  | Failed _ -> assert_failure "parse failure"
  | Success x -> assert_equal x v

let assert_parse ?(eof=true) p str =
  match parse_string ~eof p str with
  | Failed _ -> assert_failure "parse failure"
  | Success _ -> assert_bool "ok" true

let assert_parse_fail ?(eof=true) p str =
  match parse_string ~eof p str with
  | Failed _ -> assert_bool "ok" true
  | Success _ -> assert_failure "expected parse failure"

let assert_parse_map ?(eof=true) p str fn = 
  match parse_string ~eof p str with
  | Failed _ -> assert_failure "parse failure"
  | Success x -> assert_bool "map" (fn x)

let parse_tests name parse l = 
  name >::: (List.map (function
    | `Ok(str) -> 
        ("OK  : " ^ name ^ " '" ^ str ^ "'") >:: (fun () -> assert_parse parse str)
    | `Fail(str) -> 
        ("FAIL: " ^ name ^ " '" ^ str ^ "'") >:: (fun () -> assert_parse_fail parse str)
    | `Eq(str,eq) -> 
        ("EQ  : " ^ name ^ " '" ^ str ^ "'") >:: (fun () -> assert_parse_eq parse str eq)
    | `Map(str,fn) ->
        ("MAP : " ^ name ^ " '" ^ str ^ "'") >:: (fun () -> assert_parse_map parse str fn)
    ) l)

let test_typescript = 
  let open Parser in
  let open Ast in
  let open TypeScript in
  "Tests" >::: [
    "Token" >::: [
      parse_tests "whitespace_and_comments" Token.whitespace [
        `Ok "";
        `Ok " ";
        `Ok "\t";
        `Ok "\n";
        `Ok "\t\r\n ";
        `Ok "/* aaa\nbbbb */";
        `Ok "// aaa";
      ];
      parse_tests "string" (Token.string "hello") [
        `Ok "hello   ";
        `Fail "goodbye   ";
        `Eq("hello   ", "hello");
      ];
      "char" >::: [
        "simple" >:: (fun ctx -> assert_parse_eq (Token.char 'a') "a" 'a');
        "punct" >:: (fun ctx -> assert_parse_eq (Token.char ':') ":" ':');
        "space" >:: (fun ctx -> assert_parse_eq (Token.char 'a') "a " 'a');
        "fail multiple" >:: (fun ctx -> assert_parse_fail (Token.char 'a') "ab");
      ];
    ];
    "Typescript basic" >::: [
      parse_tests "identifier" identifier [
        `Ok "abc";
        `Ok "De";
        `Ok "_fg";
        `Ok "Xyz \n/* ... */ // ...";
        `Ok "1hikj";
        `Ok "$";
        `Ok "$$";
        `Ok "$_";
        `Ok "_";
        `Ok "__";
      ];
      parse_tests "path" path [
        `Ok "abc";
        `Ok "I.am.a.module.name";
        `Eq("a.b.c ", ["a";"b";"c"]);
        `Fail "";
        `Fail "a.b . c";
      ];
      parse_tests "stringLiteral" stringLiteral [
        `Fail "";
        `Eq("\"\"", "");
        `Eq("\"str lit\"", "str lit");
        `Eq("\'\'", "");
        `Eq("'str lit'", "str lit");
      ];
    ];
    "Typescript types" >::: [
      parse_tests "predefinedType" predefinedType [
        `Ok "number";
        `Ok "any";
        `Ok "boolean";
        `Ok "string";
        `Ok "void";
        `Fail "other";
      ];
      parse_tests "typeQuery" typeQuery [
        `Ok "typeof mytype";
        `Eq("typeof a.b.c", ["a";"b";"c"]);
      ];
      parse_tests "typeReference" typeReference [
        `Fail "";
        `Ok "a";
        `Ok "a<b>";
        `Ok "a<b,c>";
        `Ok "a < b, c> ";
      ];
      parse_tests "typeParameter" typeParameter [
        `Ok "b extends c";
        `Ok "b extends c.d";
      ];
      parse_tests "elementType" elementType [
        `Map("any", function `PredefinedType _ -> true | _ -> false);
        `Map("number", function `PredefinedType _ -> true | _ -> false);
        `Map("a", function `TypeReference _ -> true | _ -> false);
        `Map("typeof a", function `TypeQuery _ -> true | _ -> false);
        `Map("{}", function `ObjectType _ -> true | _ -> false);
      ];
      parse_tests "typeLiteral" typeLiteral [
        `Map("a[][]", function `ArrayType _ -> true | _ -> false);
        `Map("{}", function `ObjectType _ -> true | _ -> false);
        `Map("() => a", function `FunctionType _ -> true | _ -> false);
        `Map("<a>(b:c,d:e) => f", function `FunctionType _ -> true | _ -> false);
        `Map("new () => a", function `ConstructorType _ -> true | _ -> false);
        `Map("new <a>(b,c:d) => e<f>", function `ConstructorType _ -> true | _ -> false);
      ];
      parse_tests "type" type_ [
        `Map("a[][]", function `TypeLiteral _ -> true | _ -> false);
        `Map("{}", function `TypeLiteral _ -> true | _ -> false);
        `Map("() => a", function `TypeLiteral _ -> true | _ -> false);
        `Map("<a>(b:c,d:e) => f", function `TypeLiteral _ -> true | _ -> false);
        `Map("new () => a", function `TypeLiteral _ -> true | _ -> false);
        `Map("new <a>(b,c:d) => e<f>", function `TypeLiteral _ -> true | _ -> false);
        `Map("a", function `TypeReference _ -> true | _ -> false);
        `Map("a<b>", function `TypeReference _ -> true | _ -> false);
        `Map("a<b,c>", function `TypeReference _ -> true | _ -> false);
        `Map("a < b, c> ", function `TypeReference _ -> true | _ -> false);
        `Map("any", function `PredefinedType _ -> true | _ -> false);
        `Map("string", function `PredefinedType _ -> true | _ -> false);
        `Map("typeof t", function `TypeQuery _ -> true | _ -> false);
        `Ok "any[]";
        `Ok "string[]";
        `Ok "number[]";
        `Ok "boolean[]";
      ];
      parse_tests "object" objectType [
        `Fail "";
        `Ok "{ a }";
        `Ok "{ a; }";
        `Ok "{ a; b }";
        `Ok "{ a; b;  }";
       (* MORE *)
      ];
      parse_tests "parameter" parameter [
        `Fail "";
        `Map("a", function `RequiredParameter _ -> true | _ -> false);
        `Ok "public a";
        `Ok "private a";
        `Map("a?", function `OptionalParameter _ -> true | _ -> false);
        `Ok "private a?";
        `Ok "public a?";
        `Ok "a:b";
        `Ok "a?:b";
        `Ok "a?:b<c>";
        `Map("a:\"b\"", function `RequiredParameterSpecialized _ -> true | _ -> false);
        `Ok"a?:\"b\""; (* XXX *)
        `Map("... sommat", function `RestParameter _ -> true | _ -> false);
      ];
      parse_tests "indexSignature" indexSignature [
        `Ok "[ name : string ] : type";
        `Ok "[ name : number ] : type";
        `Fail "[ name : any ] : type";
        `Fail "[ name : number ]";
      ];
      parse_tests "constructSignature" constructSignature [
        `Ok "new ()";
        `Ok "new<a> ()";
        `Ok "new < Isla, Skye > ( isla )";
        `Ok "new ( isla : Island, harris? : Rocky<Island> )";
        `Ok "new(container: HTMLElement, theme?: string): VirtualRenderer";
      ];
      parse_tests "callSignature" callSignature [
        `Fail "";
        `Ok "()";
        `Ok "( a,b,c )";
        `Ok "( a,b:b<b>,c ) :d<e>";
        `Ok "<x,y>( a,b:b<b>,c ) :d<e>";
        `Eq("()", { csg_typeParameters=None; csg_parameterList=[]; csg_typeAnnotation=None });
      ];
      parse_tests "properySignature" propertySignature [
        `Fail "";
        `Ok "a";
        `Ok "a:b";
        `Ok "a:b<c>";
        `Ok "a:b<c>[]";
        `Ok "a:b<c,d<e>>[][][]";
      ];
      parse_tests "methodSignature" methodSignature [
        `Fail "";
        `Ok "fn()";
        `Ok "a?(b)";
        `Ok "a(b):c<d>";
        `Ok "a(b):c<d>[]";
      ];
      parse_tests "typeMember" typeMember [
        `Map("new ()", function `ConstructSignature _ -> true | _ -> false);
        `Map("a()", function `MethodSignature _ -> true | _ -> false);
        `Map("()", function `CallSignature _ -> true | _ -> false);
        `Map("[a:string]:b", function `IndexSignature _ -> true | _ -> false);
        `Map("a", function `PropertySignature _ -> true | _ -> false);
      ];
      parse_tests "exportAssignment" exportAssignment [
        `Ok("export = hello;");
      ];
      parse_tests "interfaceExtendsClause" interfaceExtendsClause [
        `Ok "extends a<b>, c";
        `Fail "extends a[]";
        `Fail "extends";
      ];
      parse_tests "interfaceDeclaration" interfaceDeclaration [
        `Ok "interface a { }";
        `Ok "interface a<b> extends c,d { }";
        `Ok "interface a { b;c:d<e>}";
        `Ok "interface a { b:Array<any>; }";
        `Ok "interface a { b:any[]; }"; 
      ];
      parse_tests "importDeclaration" importDeclaration [
        `Ok "import a = b";
        `Ok "import a = b.c";
        `Fail "import a.c = c";
      ];
      parse_tests "externalImportDeclaration" externalImportDeclaration [
        `Ok "import a = require ( \"b\" );";
        `Ok "export import a = require ( \"b\" );";
      ];
      parse_tests "ambientVariableDeclaration" ambientVariableDeclaration [
        `Ok "var a;";
        `Ok "var a:b;";
        `Ok "var a:b[];";
        `Ok "var a:b<c<d>>[];";
      ];
      parse_tests "ambientEnumDeclaration" ambientEnumDeclaration [
        `Ok "enum a { b, c }";
        `Ok "enum a { b=0, c=10 }";
      ];
      parse_tests "ambientFunctionDeclaration" ambientFunctionDeclaration [
        `Ok "function a ()";
        `Ok "function a (a,b,c:d<e>)";
      ];
      parse_tests "ambientClassDeclaration" ambientClassDeclaration [
        `Ok "class a {}";
        `Ok "class a<b> {}";
        `Ok "class a<b> extends c implements d, e {}";
        `Ok "class a { constructor (a:b,c); }";
        `Ok "class a { b:c<d>; }";
        `Ok "class a { b(); }";
        `Ok "class a { b() }";
        `Ok "class a { b(c,d:e); }";
        `Ok "class a { b }";
        `Ok "class a { b; }";
        `Ok "class a { a b }";
        `Ok "class a { a b; }";
      ];
      parse_tests "ambientModuleElement" ambientModuleElement [
        `Map("var a:b;", function `AmbientVariableDeclaration _ -> true | _ -> false);
        `Map("interface a {}", function `InterfaceDeclaration _ -> true | _ -> false);
        `Map("module a {}", function `AmbientModuleDeclaration _ -> true | _ -> false);
        `Map("import a = b.c", function `ImportDeclaration _ -> true | _ -> false);
        `Map("function a()", function `AmbientFunctionDeclaration _ -> true | _ -> false);
        `Map("enum a { b, c }", function `AmbientEnumDeclaration _ -> true | _ -> false);
        (* XXX class *)
      ];
      parse_tests "ambientModuleElementTop" ambientModuleElementTop [
        `Ok "var a : b;";
        `Ok "export var a : b;";
        `Ok "export interface SourceMapConverter {}";
      ];
      parse_tests "ambientModuleDeclaration" ambientModuleDeclaration [
        `Ok "module a { var a; var b; }";
        `Ok "module a { var a; var b }"; (* now passes *)
      ];
      parse_tests "ambientExternalModuleElement" ambientExternalModuleElement [
        `Map("module a {}", function `AmbientModuleElement _ -> true | _ -> false);
        `Map("export = hello;", function `ExportAssignment _ -> true | _ -> false);
        `Map("import a = require( \"b\" );", function `ExternalImportDeclaration _ -> true | _ -> false);
        `Map("export import a = require ( \"b\" );", 
          function `ExternalImportDeclaration _ -> true | _ -> false);
      ];
      parse_tests "ambientExternalModuleDeclaration" ambientExternalModuleDeclaration [
        `Ok "module \"x\" {}";
        `Ok "module \"x\" { var a; }";
      ];
      parse_tests "ambientDeclaration" ambientDeclaration [
        `Map("var a;", function `AmbientVariableDeclaration _ -> true | _ -> false);
        `Map("module a {}", function `AmbientModuleDeclaration _ -> true | _ -> false);
        `Map("module \"b\" {}", function `AmbientExternalModuleDeclaration _ -> true | _ -> false);
        `Map("enum a { b, c }", function `AmbientEnumDeclaration _ -> true | _ -> false);
        `Map("function a()", function `AmbientFunctionDeclaration _ -> true | _ -> false);
        (* XXX class *)
      ];
      parse_tests "declarationElement" declarationElement [
        `Map("declare var a;", function `AmbientDeclaration _ -> true | _ -> false);
        `Map("export declare module a {}", function `AmbientDeclaration _ -> true | _ -> false);
        `Map("declare module \"a\" {}", function `AmbientDeclaration _ -> true | _ -> false);
        `Map("export = a;", function `ExportAssignment _ -> true | _ -> false);
        `Map("interface a {}", function `InterfaceDeclaration _ -> true | _ -> false);
        `Map("interface a<b> extends c,d<e> { f; g:h<i> }", 
          function `InterfaceDeclaration _ -> true | _ -> false);
        `Map("import a = b.c", function `ImportDeclaration _ -> true | _ -> false);
        `Map("import a = require ( \"b\" );", function `ExternalImportDeclaration _ -> true | _ -> false);
        `Ok "declare module \"a\" {
              export interface a {
              }
             }";
      ];
      (* a bunch of example code from the TypeScript documentation *)
      parse_tests "examples" declarationSourceFile [
        `Ok "declare function vote(candidate: string, callback: (result: string) => any)";
        `Ok "
          interface Friend {
            name: string;
            favoriteColor?: string;
          }";
        `Ok "
          interface JQuery {
            text(content: string);
          }
          interface JQueryStatic {
            get(url: string, callback: (data: string) => any);
            (query: string): JQuery;
          }
          declare var $: JQueryStatic;"; (* XXX $ is valid identifier *)
        `Ok "
          interface Point {
            x: number;
            y: number;
          }";
        `Ok "
          declare class CPoint {
            x: number;
            y: number;
            constructor(x: number, y: number);
          }";
        `Ok "
          interface BankAccount {
            balance: number;
            deposit(credit: number): number;
          }
          declare var BankAccount: new() => BankAccount;";
        `Ok "
          declare enum Operator {
            ADD,
            DIV,
            MUL,
            SUB
          } ";
        `Ok "
          interface Array<T> {
            reverse(): T[];
            sort(compareFn?: (a: T, b: T) => number): T[];
            map<U>(func: (value: T, index: number, array: T[]) => U, thisArg?: any): U[];
          }";
        `Ok "
          interface M {
            f(): string;
          }
          declare var M: M; ";
        `Ok "
          declare module X {
            export module Y {
              export interface Z { }
            }
            export interface Y { }
          }
          declare module A {
            export module B {
              export class C { }
            }
          } ";
        `Ok "
          interface G<T, U extends Function> {
            f<V extends U>(x: V): V;
          } ";
        `Ok "
          interface Pair<T1, T2> { first: T1; second: T2; }
          declare var a : Pair<string,Entity>;
          declare var b : { first: string; second: Entity; };
        ";
        `Ok "
          interface A { a: string; }
          interface B extends A { b: string; }
          interface C extends B { c: string; }
          interface G<T, U extends B> {
            x: T;
            y: U;
          }
        ";
        `Ok "
          declare var v1: {
            x: { a: string; };
            y: { a: string; b: string; c: string };
          }; ";
        `Ok "
          interface Document {
            createElement(tagName: \"div\"): HTMLDivElement;
            createElement(tagName: \"span\"): HTMLSpanElement;
            createElement(tagName: \"canvas\"): HTMLCanvasElement;
            createElement(tagName: string): HTMLElement;
          } ";
        `Ok "
          declare var x:
            {
              func1(x: number): number;
              func2: (x: number) => number;
              func3: { (x: number): number };
            };
          declare var y:
            {
              func4(x: number): number;
              func4(s: string): string;
              func5: {
                (x: number): number;
                (s: string): string;
              };
            }; ";
        `Ok "
          declare class C<T> { private x: T; }
          interface X { f(): string; }
          interface Y { f(): string; }
          declare var a: C<X>;
          declare var b: C<Y>; ";
        `Ok "
          interface List<T> {
            data: T;
            next: List<T>;
            owner: List<List<T>>;
          } ";
        `Ok "
          interface EventObject {
            x: number;
            y: number;
          }
          interface EventHandlers {
            mousedown?: (event: EventObject) => void;
            mouseup?: (event: EventObject) => void;
            mousemove?: (event: EventObject) => void;
          }
          declare function setEventHandlers(handlers: EventHandlers) ";
        `Ok "
          declare var attr: {
            (name: string): string;
            (name: string, value: string): Accessor;
            (map: any): Accessor;
          }; ";
        `Ok "
          interface Mover {
            move(): void;
            getStatus(): { speed: number; };
          }
          interface Shaker {
            shake(): void;
            getStatus(): { frequency: number; };
          }
          interface MoverShaker extends Mover, Shaker {
            getStatus(): { speed: number; frequency: number; };
          } ";
        `Ok " interface StringComparer { (a: string, b: string): number; } ";
        `Ok "
          interface Document {
            createElement(tagName: any): Element;
          }
          interface Document {
            createElement(tagName: string): HTMLElement;
          }
          interface Document {
            createElement(tagName: \"div\"): HTMLDivElement;
            createElement(tagName: \"span\"): HTMLSpanElement;
            createElement(tagName: \"canvas\"): HTMLCanvasElement;
          } ";
        `Ok "
          declare class A { a: number; }
          declare module Foo {
            var A;
            class B extends A { b: string; }
          } ";
        `Ok "
          interface A {
            x: number;
            f: () => void;
            g: (a: any) => any;
          }
          interface B {
            x: number;
            y: number;
            f: () => void;
            g: (b: boolean) => boolean;
          } ";
        `Ok "
          declare class Pair<T1, T2> {
            constructor(public item1: T1, public item2: T2);
          }
          declare class TwoArrays<T> extends Pair<T[], T[]> {}
          interface Pair<T1, T2> {
            item1: T1;
            item2: T2;
          }
          interface TwoArrays<T> {
            item1: T[];
            item2: T[];
          }
          declare var Pair: {
            new <T1, T2>(item1: T1, item2: T2): Pair<T1, T2>;
          };
          declare var TwoArrays: {
            new <T>(item1: T[], item2: T[]): TwoArrays<T>;
          };
        ";
        `Ok "
          interface Point {
            x: number;
            y: number;
            distance(p: Point);
          }
          declare var Point: {
            new(x: number, y: number): Point;
            origin: Point;
            distance(p1: Point, p2: Point): number;
          }; ";
        `Ok "
          declare enum Color { Red, Green, Blue }
          declare var Color: {
            [x: number]: string;
            Red: Color;
            Green: Color;
            Blue: Color;
          }; ";
        `Ok "
          declare module A {
            export interface X { s: string }
            export var X: X;
          } ";
        `Ok "
          interface A { x: string; }
          declare module M {
            export interface B { x: A; }
            export interface C { x: B; }
            function foo(c: C)
          } ";
      ];
    ];
  ]

let run () = 
  run_test_tt_main test_typescript |> ignore


