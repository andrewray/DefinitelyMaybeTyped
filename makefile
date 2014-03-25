.PHONY: all clean byte native

all: byte

byte:
	ocamlbuild -use-ocamlfind otypescript.byte

native:
	ocamlbuild -use-ocamlfind otypescript.native

clean:
	- rm -fr *~
	ocamlbuild -clean
