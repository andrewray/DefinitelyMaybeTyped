.PHONY: all clean byte native

all: byte native

byte:
	ocamlbuild -use-ocamlfind otypescript.byte

native:
	ocamlbuild -use-ocamlfind otypescript.native

ts:
	tsc -d test/test.ts

js: 
	ocamlbuild -use-ocamlfind jsserver.byte
	ocamlbuild -use-ocamlfind test_ml.byte
	js_of_ocaml -pretty -debuginfo -sourcemap test_ml.byte -o test/test_ml.js

lib.ml:
	./otypescript.byte -i ../forks/DefinitelyTyped/_infrastructure/tests/typescript/0.9.7/lib.d.ts

test_lib.byte: lib.ml test_lib/test_lib.ml
	ocamlbuild -use-ocamlfind test_lib.byte

test_lib.js: test_lib.byte
	js_of_ocaml test_lib.byte

clean:
	- rm -fr *~
	- rm -fr test/*~
	- rm test/test.d.ts test/test.js test/test_ml.js test/test.map
	ocamlbuild -clean
