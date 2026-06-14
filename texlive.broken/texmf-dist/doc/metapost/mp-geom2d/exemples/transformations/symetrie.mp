input geom2d;

beginfig(1);

A = Point(2,2);
a = Point(-1,-1);
b = Point(2,0);
c = Point(3,-2);
aa = Point(-1,-1.5);
DD = Droite(aa,c);
D = Droite(a,b);
B = SymetrieAxialePoint(A,D);
pointe A;
pointe B;
trace D;
C = Cercle(A,2);
P = ParaboleFD(A,DD);
trace C;
CC = SymetrieAxiale(C,D);
PP = SymetrieAxiale(P,D);
trace CC;
trace P;
trace PP;

endfig;
end.