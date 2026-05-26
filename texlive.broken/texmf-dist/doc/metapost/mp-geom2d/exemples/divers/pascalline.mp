input geom2d;

beginfig(1);
C = Cercle(origine,3);
for i:=1 upto 6:
    rd := uniformdeviate(1.0/6)+(i-1)/6;
    P[i] := PointDe(C,rd);
endfor; 
D1 = Droite(P1,P3); S1 = Segment(P1,P3);
D2 = Droite(P3,P5); S2 = Segment(P3,P5);
D3 = Droite(P6,P2); S3 = Segment(P6,P2);
D4 = Droite(P4,P6); S4 = Segment(P4,P6);
D5 = Droite(P5,P2); S5 = Segment(P5,P2);
D6 = Droite(P1,P4); S6 = Segment(P1,P4);
I1 = IntersectionDroites(D1,D3);
I2 = IntersectionDroites(D2,D4);
I3 = IntersectionDroites(D5,D6);
PL = Segment(I1,I2);
trace C;
drawoptions(withcolor (0.7,0.1,0.1));
trace S1; trace S2; trace S3; trace S4; trace S5; trace S6;
drawoptions(withcolor (0.1,0.7,0.1));
trace PL;
drawoptions();
pointe(P1); pointe P2; pointe P3; pointe P4; pointe P5; pointe P6;
pointe I1; pointe I2; pointe I3;
endfig;
end.