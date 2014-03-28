(* hacks *)
type typeReference
type typeQuery
type typeLiteral

(* predefined types *)
type any = Js.Unsafe.any
type number = float Js.t
type string = Js.js_string Js.t
type boolean = bool Js.t
type void = unit 
