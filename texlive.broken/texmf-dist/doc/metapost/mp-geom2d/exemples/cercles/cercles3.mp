input geom2d;

labeloffset := 6;

gddTaillePoint := 2;
gddCouleurPoint := Yellow;



beginfig(1);


  C1 = Cercle((1,1),3);
  C2 = Cercle((-3,-3),1);

  T1 = TangenteCommuneExterieure(C1,C2);
  T2 = TangenteCommuneExterieure(C2,C1);
  T3 = TangenteCommuneInterieure(C1,C2);
  T4 = TangenteCommuneInterieure(C2,C1);
  
  
  drawoptions(withcolor LightSlateGrey);
  trace C1;
  trace C2;

  drawoptions(withcolor Olive);
  trace T1;
  trace T2;


  drawoptions(withcolor DarkRed);
  trace T3;
  trace T4;

  drawoptions();
  pointe Centre(C1);
  pointe Centre(C2);

  a = angle((0,-1));
  show a;

endfig;

beginfig(2);

  A = Point(0,0);
  B = Point(2,1);
  C = Point(1,3);

  K = CercleTroisPoints(A,B,C);

  trace K;
  pointe A;
  pointe B;
  pointe C;
endfig;

end
