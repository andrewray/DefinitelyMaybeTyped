
(********************************************************************************)
(* file utilities *)

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

let with_file name f = 
  let file = open_in name in
  try
    let r = f file in
    close_in file;
    r
  with x -> 
    close_in file;
    raise x

(********************************************************************************)
(* command line *)

let parse_file name = with_file name (Parser.parse name)
let parse_dir dir = 
  List.iter 
    (fun name -> 
      try 
        with_file name (Parser.parse ~fail:false name)
      with _ ->
        Printf.printf "exn : %s\n%!" name)
    (findall dir)

let () = 
  let open Arg in
  parse (align [
    "-i", String(parse_file), "<file> Parse typescript definition file";
    "-d", String(parse_dir), 
      "<dir> Find all typescript definition files in directory and parser them";
    "-t", Unit(Unit_tests.run), " run unit tests";
  ]) 
  (fun _ -> failwith "anon args not allowed")
  "otypescript"


