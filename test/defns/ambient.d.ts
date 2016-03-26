// Variables
declare var a : any;
export declare var b;
declare var c : (a,b,c:"hi",d?:"bye",...anon) => string;
declare var d : new (a,b?) => number;
declare var e : { x:boolean; y:void; }
declare var f : typeof a;
declare var g : any[];
declare var h : {
  [ x : number ] : A.b[];
  [ y : string ] : {x}[];
  z : new <T>(a,b) => c;
  f(a):b;
  f?(a):b;
  new<T>(a : number) : any;
  (a,b) : c;
  l? : T<any>;
};

// Functions
declare function a(b) : c;
export declare function a(b) : c;

// Class
export declare class A { }
declare class B { 
  //[ x : number ] : b; XXX doesnt work ???
  private a : b;
  static a(a):a;
  constructor();
}

