input geom2d;

beginfig(1);
gddPointeType:="croix";
A = Point(1,1);
pointe A avecCrayon(1,green);
B = Point(4,4);

CA = CercleD(A,1);
trace CA;
CB = CercleD(B,2);
trace CB;
%C = IntersectionCercles(CA,CA);
%trace C;
D = Point(2,3);
E = Point(4,-1);
DE = Droite(D,E);
trace DE;
%C = IntersectionDroiteCercle(DE,CA,1);
%pointe C;
endfig;
end.