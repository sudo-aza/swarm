input geom2d;

beginfig(1);
  A = Point(0,0);
  B = Point(3,2);
  AB = Droite(A,B);
  F_1 = Point(-1,1);
  Hyper = HyperboleFD(F_1,AB,1.5);
  %trace AB;
  trace DemiHyperbole(Hyper,1);
  E = EllipseFD(F_1,AB,0.7);
  trace E;
  D = Droite(Foyer(E,1),Foyer(E,2));
  trace D;
  trace Directrice(E,1);
  trace Directrice(E,2);
  

endfig;

beginfig(2);
    C := Point(3,2);
    A := Point(5,1);
    B := Point(3.5,3) ;
    E := Ellipse(C,A,B);
    F := EllipseF(C,A,2.5);
    D := Centre(F);
    pointe D;
    trace E;
    trace F;
    pointe C;
    pointe A;
    pointe B;
    %trace Directrice(E,1);
    %trace Directrice(E,2);
    trace Directrice(F,1);
    trace Directrice(F,2);
endfig;
end.
