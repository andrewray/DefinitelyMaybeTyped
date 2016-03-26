// Indexed interface
interface A {
  [index : string] : string
}

// Extend A with appropriate properties
// all properties must have the same type as the indexer.
interface A {
  a : string;
  b : string;
  c : string;
}

// you cannot, it seems, have functions
//interface A {
//  d(a:number) : string;
//}

var x : A = {a:"a", b:"b", c:"c" };
var y = x["x"]


