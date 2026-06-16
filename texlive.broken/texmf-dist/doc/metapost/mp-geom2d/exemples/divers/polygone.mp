input geom2d;

beginfig(1);
 

  A = Point(0,0);
  B = Point(3,3);
  C = Point(3,4);
  D = Point(2,2.4);
  F = Point(0,5);
  G = Barycentre(A,B,C,D,F);
  P = Polygone(A,B,C,D,F);
  Q1 = PolygoneRegulier(10,2,0,(2,2));
  trace(P);
  pointe(G);
  trace(Q1);
  pointe(PointPolygone(Q1,1));
  pointe(CentrePolygone(Q1));
endfig;
end