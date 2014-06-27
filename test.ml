(* interfaceDeclaration *)
class type _A = object
method a : Ts.boolean -> Ts.void Js.meth
method a_1 : Ts.number -> Ts.void Js.meth
end
(* interfaceDeclaration *)
class type _A = object
method a : Ts.string -> Ts.void Js.meth
end
(* ambientFunctionDeclaration *)
let _A : Ts.string -> Ts.void = fun p0 -> Js.Unsafe.fun_call (Js.Unsafe.variable "A") [| Js.Unsafe.inject p0;  |]
(* AmbientDeclaration *)
(* AmbientDeclaration *)
(* ambientFunctionDeclaration *)
let temp : Ts.boolean -> Ts.number = fun p0 -> Js.Unsafe.fun_call (Js.Unsafe.variable "temp") [| Js.Unsafe.inject p0;  |]
