let w : Lib._Object Js.t = Js.Unsafe.variable "window"

let log s = Firebug.console##log(s)
let olog s = log (Js.string s)

(* check some Object methods *)

let () = log (w##toString(()))

let () = log (w##toLocaleString(()))

let hasProp s = 
  if w##hasOwnProperty(Js.string s) = Js._true then
    log (Js.string ("has property " ^ s))
  else
    log (Js.string ("does not have property " ^ s))

let () = hasProp "Intl"
let () = hasProp "blah"

(* String *)

let str : Lib._String Js.t = Obj.magic (Js.string "hello world")

let () = log str
let () = log (str##substring(6.,11.))
let () = olog (string_of_float (str##length))

(* Math *)

(*let math : Lib._Math Js.t = (Js.Unsafe.variable "window")##_Math*)
let math = Lib._Math (* via a hack to lib.ml *)

let () = olog (string_of_float (math##sqrt(4.)))
let () = olog (string_of_float (math##_E))

(* Date *)

let date : Lib._Date Js.t = (Js.Unsafe.variable "window")##_Date

(* object literal for date object, not implemented *)



