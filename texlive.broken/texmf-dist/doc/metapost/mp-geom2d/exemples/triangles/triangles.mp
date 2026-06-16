input geom2d;

beginfig(1);

    A = Point(0,0);
    B = Point(7,0.3);
    C = Point(1,3);
    TABC = Triangle(A,B,C);
    D = Orthocentre(TABC);
    C_C = CercleCirconscrit(TABC);
    C_E = CercleEuler(TABC);
    trace TABC;
    trace C_C withcolor DarkBlue;
    trace C_E withcolor DarkRed;
    pointe A;
    pointe B;
    pointe C;
    pointe D;
    pointe Centre(C_C);
    pointe Centre(C_E);
    marque.lft "A";
    marque.rt "B";
    marque.lft "C";
    marque.rt "D";
endfig;

end.