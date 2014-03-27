all: server.byte test_ml.js test.js

server.byte: server.ml
	ocamlfind ocamlc -linkpkg -package findlib,cohttp.lwt server.ml -o server.byte

test.js: test.ts
	tsc -d test.ts

test_ml.byte: test_ml.ml
	ocamlfind c -o test_ml.byte -syntax camlp4o \
		-package js_of_ocaml,js_of_ocaml.syntax \
		-linkpkg test_ml.ml

test_ml.js: test_ml.byte
	js_of_ocaml test_ml.byte

clean:
	- rm test.js test.d.ts test_ml.js *.cmo *.cmi *.byte *~
