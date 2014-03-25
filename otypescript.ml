
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

let preprocess input_name = 
  let base = Filename.basename input_name in
  let output_name = Filename.concat "dump" base in
  let command = "cpp -P " ^ input_name ^ " " ^ output_name in
  Printf.printf "%s\n%!" command;
  Unix.system command |> ignore

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

let parse_file name = with_file name (Parser.parse name) |> ignore
let parse_dir dir = 
  let pass, fail, exn = ref 0, ref 0, ref 0 in
  List.iter 
    (fun name -> 
      try 
        if with_file name (Parser.parse ~fail:false name) then incr pass
        else incr fail
      with _ -> begin
        Printf.printf "exn : %s\n%!" name;
        incr exn;
      end)
    (findall dir);
  Printf.printf "pass=%i fail=%i exn=%i\n" !pass !fail !exn

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


