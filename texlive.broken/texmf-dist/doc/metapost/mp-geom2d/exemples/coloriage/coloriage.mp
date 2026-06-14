input geom2d;

beginfig(1);

A = Point(-1,1);
B = Point(3,2);
C1= Cercle(origine,2);
C2 = Cercle(A,2);
C3 = Cercle(B,3);

colorie C1 withcolor LightCyan;
colorieAvecTransparence(C2,DarkRed,0.2);
colorieAvecTransparence(C3,DarkBlue,0.2);

T1 = Triangle((-1,-2),(2,-2),(0.2,1));
trace hachure(T1,45,0.2,0);
trace T1;
pE1 = Point(-2,-3); pointe pE1;
pE2 = Point(3,-4); pointe pE2;
E = EllipseF(pE1,pE2,3.9);
trace hachure(E,-20,0.1,3);
trace E;


endfig;

end.