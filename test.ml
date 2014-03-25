(*********************************************************************************)

(* path to DefinitelyTypes *)
let path = "/home/andyman/dev/github/DefinitelyTyped"

let filenames = List.map (Filename.concat path)
[
  "accounting/accounting.d.ts";
  "ace/ace.d.ts";
]

(* all files in path *)
(*let filenames = List.sort compare (findall path)*)

(* main typescript definitions *)
let lib = "/home/andyman/dev/github/DefinitelyTyped/_infrastructure/tests/typescript/0.9.7/lib.d.ts"

(*********************************************************************************)

let rec readall path = 
  let open Unix in
  let h = opendir path in
  let rec read () = 
    match try Some(readdir h) with _ -> None with
    | None -> []
    | Some(x) when x<>"." && x<>".." -> (Filename.concat path x)::read()
    | _ -> read()
  in
  let all = read() in
  closedir h;
  all

let rec findall path = 
  let open Unix in
  let all = readall path in
  (* partition into sub-dirs and .d.ts files *)
  let rec classify dirs dts = function
    | [] -> dirs, dts
    | h::t ->
      match (stat h).st_kind with
      | S_DIR -> classify (h::dirs) dts t
      | S_REG when Filename.check_suffix h ".d.ts" -> classify dirs (h::dts) t
      | _ -> classify dirs dts t
  in
  let dirs, dts = classify [] [] all in
  List.fold_left (fun dts dir -> dts @ findall dir) dts dirs

let preprocess input_name = 
  let base = Filename.basename input_name in
  let output_name = Filename.concat "dump" base in
  let command = "cpp -P " ^ input_name ^ " " ^ output_name in
  Printf.printf "%s\n%!" command;
  Unix.system command |> ignore

(* read file into a string *)
let data fname = 
  let file = open_in fname in
  let b = Buffer.create 1024 in
  let add s = Buffer.add_string b s; Buffer.add_string b "\n" in
  let rec f () = 
    match (try Some(input_line file) with _ -> None) with
    | Some(x) -> add x; f ()
    | None -> Buffer.contents b
  in 
  let s = f () in
  let _ = close_in file in
  s

(* find all defintion files in DefinitelyTyped *)
let all () = findall path

let with_file name f = 
  let file = open_in name in
  try
    let r = f file in
    close_in file;
    r
  with x -> 
    close_in file;
    raise x

(* split test into those which pass or fail and those which raise exceptions *)
let rec test1 pass_fail exn = function 
  | [] -> pass_fail,exn
  | h::t -> begin
    try
      with_file h (Parser.parse ~fail:false h);
      test1 (h::pass_fail) exn t
    with _ ->
      test1 pass_fail (h::exn) t
  end

(*********************************************************************************)
(* unit tests *)

let _ = Unit_tests.run ()

(*let _ = List.iter (parse ~fail:false) filenames *)
(*
let main = 
    if not !Sys.interactive then begin
      let filename = Sys.argv.(1) in
      parse filename
    end
*)
