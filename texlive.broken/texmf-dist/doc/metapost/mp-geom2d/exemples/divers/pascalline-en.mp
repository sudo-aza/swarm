input geom2d;

beginfig(1);
C = Circle(origine,3);
for i:=1 upto 6:
    rd := uniformdeviate(1.0/6)+(i-1)/6;
    P[i] := PointOf(C,rd);
endfor; 
D1 = Line(P1,P3); S1 = Segment(P1,P3);
D2 = Line(P3,P5); S2 = Segment(P3,P5);
D3 = Line(P6,P2); S3 = Segment(P6,P2);
D4 = Line(P4,P6); S4 = Segment(P4,P6);
D5 = Line(P5,P2); S5 = Segment(P5,P2);
D6 = Line(P1,P4); S6 = Segment(P1,P4);
I1 = LinesIntersection(D1,D3);
I2 = LinesIntersection(D2,D4);
I3 = LinesIntersection(D5,D6);
PL = Segment(I1,I2);
gddDraw C;
drawoptions(withcolor (0.7,0.1,0.1));
gddDraw S1; gddDraw S2; gddDraw S3; gddDraw S4; gddDraw S5; gddDraw S6;
drawoptions(withcolor (0.1,0.7,0.1));
gddDraw PL;
drawoptions();
gddDrawPoint P1; gddDrawPoint P2; gddDrawPoint P3; gddDrawPoint P4; gddDrawPoint P5; gddDrawPoint P6;
gddDrawPoint I1; gddDrawPoint I2; gddDrawPoint I3;
endfig;
end.