input geom2d;

beginfig(1);

F1 = Point(-2,1);
F2 = Point(2,-1);
E1 = EllipseF(F1,F2,2.5);
E2 = EllipseF(F1,F2,4);
Dir = Directrix(E1,1);
H1 = HyperbolaF(F1,F2,1.9);
H2 = HyperbolaF(F1,F2,1.1);


s1H1 = Chemin(SemiHyperbola(H1,1));
s2H1 = Chemin(SemiHyperbola(H1,2));
s1H2 = Chemin(SemiHyperbola(H2,1));
s2H2 = Chemin(SemiHyperbola(H2,2));

gddDraw E1;
gddDraw E2;
gddDraw s1H1;
gddDraw s2H1;
gddDraw s1H2;
gddDraw s2H2;
P1 = IntersectionPoint(E1,s1H1);
P2 = IntersectionPoint(E2,s1H1);
P3 = IntersectionPoint(E1,s1H2);
P4 = IntersectionPoint(E2,s1H2);

P14 = Segment(P1,P4);
P23 = Segment(P2,P3);

gddDraw P14;
gddDraw P23;
gddDraw LineMark(P14,1);
gddDraw LineMark(P23,1);
gddDrawPoint F1;
gddDrawPoint F2;
gddMark.urt "P1";
gddMark.urt "P2";
gddMark.urt "P3";
gddMark.urt "P4";
Window(-6,-6,6,6);
endfig;

end