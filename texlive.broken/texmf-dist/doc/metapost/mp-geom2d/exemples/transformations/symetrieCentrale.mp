input geom2d;

beginfig(1);

A = Point(2,2);
a = Point(-1,-1);
b = Point(2,0);
c = Point(3,-2);
aa = Point(-1,-1.5);
DD = Droite(aa,c);
D = Droite(a,b);
B = SymetrieCentralePoint(A,a);
pointe a avecCrayon(1,red);
pointe A;
pointe B;
%trace D;
C = Cercle(A,2);
P = ParaboleFD(A,DD);
trace C;
CC = SymetrieCentrale(C,a);
PP = SymetrieCentrale(P,a);
trace CC;
trace P;
trace PP;

endfig;
end.