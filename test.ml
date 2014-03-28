
let with_file name f = 
  let file = open_in name in
  try
    let r = f file in
    close_in file;
    r
  with x -> 
    close_in file;
    raise x

let file_name = "../DefinitelyTyped/jquery/jquery.d.ts"
let ast = with_file file_name (Parser.parse file_name)

let _ = Convert.declarationElement print_string 
  (match ast with None -> failwith "invalid ast"
                | Some(x) -> List.hd x)



