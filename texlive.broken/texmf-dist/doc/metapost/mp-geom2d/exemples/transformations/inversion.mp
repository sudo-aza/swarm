input geom2d;

beginfig(1);
A = Point(2,2);
C = Cercle(A,2);
trace C;
marque.rt "A";
B = Point(0,1);
D = Inversion(B,C);
drawoptions(withcolor DarkRed);
CB = Cercle(B,1);
trace CB;
CD = Inversion(CB,C);
trace CB;
trace CD;
 marque.rt "B";  marque.rt "D";

drawoptions(withcolor DarkBlue);
E = Point(3,1);
CE = Cercle(E,0.5);
trace CE;
marque.rt "E";
iCE = Inversion(CE,C);
trace iCE;


drawoptions(withcolor DarkGreen);
d = Droite((3,3),(4,2));
trace d;
Cd = Inversion(d,C);
trace Cd;

drawoptions(withcolor Salmon);
S = Point(1,3);
CS = CercleCP(S,A);
trace CS;
dS = Inversion(CS,C);
trace dS;
endfig;
end.