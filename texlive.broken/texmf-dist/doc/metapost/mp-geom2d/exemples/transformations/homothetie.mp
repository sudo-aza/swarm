input geom2d;

beginfig(1);
    O = Point(0,0);
    P = Point(2,1);
    A = Point(3,2);
    Q = Point(-1,2);
    R = Point(0,4);
    B = Homothetie(A,P,3);
    fleche Segment(O,P);
    fleche Segment(P,A);
    fleche Segment(A,B);

    T = Triangle(A,Q,R);
    T'= Homothetie(T,P,3);
    trace T;
    trace T';

    C = Cercle(A,1.5);
    trace C;
    CC = Homothetie(C,P,3);
    trace CC; 

    path p;
    p:=Pt(A)..Pt(Q)..Pt(R);
    W = Chemin(p);
    trace W;
    X = Homothetie(W,P,3);
    trace X;

    Q1 = PolygoneRegulier(10,2,0,(2,2));
    trace Q1;
    Q2 = Homothetie(Q1,P,3);
    trace Q2;
endfig;
end.