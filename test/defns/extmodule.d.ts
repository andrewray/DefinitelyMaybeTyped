export = a;
import a = require("b");

declare module "test" {

  var a : b;
  function a(b:c):d;

  import hello = require("balloon"); // stray semi

  export = toto;

}

