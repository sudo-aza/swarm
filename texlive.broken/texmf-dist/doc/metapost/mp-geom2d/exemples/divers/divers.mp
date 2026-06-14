input geom2d;

beginfig(1);

A = Point(2,2);
B = Rotation(A,Pi/2);
pointe origine;
pointe A;
pointe B;
C = RotationCentre(B,A,Pi/2);
pointe C; 

endfig;
end.