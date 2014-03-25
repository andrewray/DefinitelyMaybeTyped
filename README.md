DefinitelyMaybeTyped
====================

[TypeScript](http://www.typescriptlang.org) adds a static typing scheme to JavaScript.  
[DefinitelyTyped](https://github.com/borisyankov/DefinitelyTyped) provides a large repository
of TypeScript definition files for JavaScript libraries.

The burning question is *can TypeScript definitions be _usefully_ converted to OCaml for use with
js\_of\_ocaml?*

There are three parts to this

1. Parse the TypeScript definition files
2. Define a mapping from the TypeScript to OCaml type system.
3. As automatically as possible do the conversion

# Status

A rough and ready parser which can successfully parse a few defintion files.

### Known issues

* Terrible error localisation
* Array annotations not properly parsed
* Stack blowup

