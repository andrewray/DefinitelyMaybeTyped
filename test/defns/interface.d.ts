export interface A {
  a : B<number>;
  b : typeof a;
  c : any;
  d : number;
  e : boolean;
  f : void;
  g? : string;
  new<T>(a : number) : any;
  h : (a,b) => c;
  <T,S>(a,b) : x;
  [ ident : number ] : A;
  [ ident : string ] : A;
  i : { x; y };
  ctr : new () => A;
}

export interface B<c> extends A {
  w : { a : b; c : d; } [];
  x : B.t [];
  //y : typeof s.s []; // hmmm...this seems like it should work
  z : any [][];
  f(public a : any, private b? : any) : any;
  g?(a:"hello",b?:"goofy",...hi : any[]);
  h : (a, b) => any;
  //new <A> (b,c:boolean) : Object;// => any;
}


