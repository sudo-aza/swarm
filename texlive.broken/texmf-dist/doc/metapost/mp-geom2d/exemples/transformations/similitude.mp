input geom2d;

beginfig(1);
    O = Point(0,0);
    P = Point(2,1);
    A = Point(3,2);
    Q = Point(-1,2);
    R = Point(0,4);
    B = SimilitudeACentre(A,P,Pi/3,0.7);
    marque.bot "P";

    T = Triangle(A,Q,R);
    T'= SimilitudeACentre(T,P,Pi/3,0.7);
    trace T;
    trace T';

    C = Cercle(A,1.5);
    trace C;
    CC = SimilitudeACentre(C,P,Pi/3,0.7);
    trace CC; 


    Q1 = PolygoneRegulier(10,2,0,(2,2));
    trace Q1;
    Q2 = SimilitudeACentre(Q1,P,Pi/3,0.7);
    trace Q2;
endfig;
end.