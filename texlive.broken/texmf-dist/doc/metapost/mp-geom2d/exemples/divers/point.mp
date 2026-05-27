input geom2d;

beginfig(0);

 C = Point(3,2);
 A = Point(5,1);
 B = Point(3.5,3) ;
 E = Ellipse(C,A,B);
 trace E;
for i=0 step 0.1 until 1:
pointe PointDe(E,i);
endfor

T = Triangle(A,B,C);
trace T;

for i=0 step 0.1 until 1:
pointe PointDe(T,i);
endfor

pointe PointDe(0.33333,T);

endfig;

end.
