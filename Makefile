.PHONY: all clean 

all: setup.data
	ocaml setup.ml -build

setup.ml:
	oasis setup

setup.data: setup.ml
	ocaml setup.ml -configure

install: all
	ocaml setup.ml -install

uninstall: 
	ocamlfind remove otypescript

#######################################################
#ts:
#	tsc -d test/test.ts
#
#js: 
#	ocamlbuild -use-ocamlfind jsserver.byte
#	ocamlbuild -use-ocamlfind test_ml.byte
#	js_of_ocaml -pretty -debuginfo -sourcemap test_ml.byte -o test/test_ml.js
#
#lib.ml:
#	./otypescript.byte -i ../forks/DefinitelyTyped/_infrastructure/tests/typescript/0.9.7/lib.d.ts
#
#test_lib.byte: lib.ml test_lib/test_lib.ml
#	ocamlbuild -use-ocamlfind test_lib.byte
#
#test_lib.js: test_lib.byte
#	js_of_ocaml test_lib.byte
#######################################################

bisect:
	bisect-report -I _build -html cov bisect*.out

bisect-clean:
	- rm -fr cov
	- rm bisect*.out

#######################################################

clean: bisect-clean
	- rm -fr *~
	- rm -fr test/*~
	- rm test/test.d.ts test/test.js test/test_ml.js test/test.map
	ocaml setup.ml -clean

