interface vec_i {
  x:number;
  y:number;
}

// 1st pass, merge interfaces - even though z is declared later, it
// is needed here.
var myvec_1 : vec_i = { x:2, y:3, z:0 }

class vec {
  // public parameters create public properties
  constructor(public x : number, public y : number) { }
  add(z:number) : void {
    this.x = this.x + z;
    this.y = this.y + z;
  }
  add2(v:vec_i) : void {
    this.x = this.x + v.x;
    this.y = this.y + v.y;
  }
}

interface vec_i {
  z : number;
}

interface luminance {
  brigthness : string;
}

interface combined extends vec_i, luminance {
  xxx : boolean;
}

var myvec_i : vec_i = { x:2, y:3, z:4 };
var myvec = new vec(0,1);
myvec.add2(myvec_i);

