class type vec = object
  method x : int Js.readonly_prop
  method y : int Js.readonly_prop
  method add : int -> unit Js.meth
end

class type vec_i = object
  method x : int Js.prop
  method y : int Js.prop
end

let vec : (int -> int -> vec Js.t) Js.constr = 
  Js.Unsafe.variable "vec"

let send_to_page div_name = 
  let doc = Dom_html.document in
  let pre = Dom_html.createPre doc in
  pre##style##borderStyle <- Js.string "inset";
  pre##style##padding <- Js.string "5";
  Dom.appendChild doc##body pre;
  (fun s -> pre##innerHTML <- Js.string (Js.to_string pre##innerHTML ^ s))

let init () = 
  let load_from_server path =
      try
        let xml = XmlHttpRequest.create () in
        xml##_open(Js.string "GET", Js.string ("http://127.0.0.1:8888/filesys" ^ path), Js._false);
        xml##send(Js.null);
        if xml##status = 200 then
          let resp = xml##responseText in
          let len = resp##length in
          let str = String.create len in
          for i=0 to len-1 do
              str.[i] <- Char.chr (int_of_float resp##charCodeAt(i) land 0xff)
          done;
          Some(str)
        else
          None
      with _ ->
        None
  in
  Sys_js.register_autoload "" load_from_server;
  Sys_js.set_channel_flusher stdout (send_to_page "stdout");
  Sys_js.set_channel_flusher stderr (send_to_page "stderr");
  Firebug.console##log(Js.string "test_ml")

let summary () = 
  (* load AST *)
  let f = open_in "out.m" in
  let ast : Ast.declarationElement list option = Marshal.from_channel f in
  let () = close_in f in

  let elements : (int * string * string) list ref = ref [] in
  let module S = Summary.Make(struct
    let show level t n = 
      elements := (level,t,n) :: !elements
  end) in
  let () = S.ast ast in
  let elements = List.rev !elements in

  (* create div list container *)
  let doc = Dom_html.document in
  let div = Dom_html.createDiv doc in
  Dom.appendChild doc##body div;

  let rec build_list parent prev level elements = 
    match elements with
    | [] -> []
    | (l,t,n)::tl ->
        if level = l then begin
          (* add to current parent, recurse *)
          let il = Dom_html.createLi doc in
          il##innerHTML <- Js.string ("<code>" ^ t ^ "</code> <i style=\"color:darkgreen\">" ^ n ^ "</i>");
          Dom.appendChild parent il;
          build_list parent il level tl
        end else if level < l then begin
          (* create new ul, add it to prev, recurse *)
          let ul = Dom_html.createUl doc in
          Dom.appendChild prev ul;
          let elements = build_list ul ul (level+1) elements in
          build_list parent prev level elements
        end else 
          (* drop back a level *)
          elements
  in
  let ul = Dom_html.createUl doc in
  ul##id <- Js.string "expList";
  Dom.appendChild div ul;
  let _ = build_list ul ul 0 elements in
  Js.Unsafe.fun_call (Js.Unsafe.variable "window.prepareList") [||] |> ignore

let main _ = 
  let () = init () in
  let () = summary() in
  let vec = jsnew vec(3,4) in
  let () = vec##add(2) in
  Js._true

let _ = Dom_html.window##onload <- Dom_html.handler main


