input geom2d;

beginfig(1);
    A = Point(2,0);
    B = Point(3,3);
    C = Vecteur(2,2);
    D = Segment(A,B);
    fleche C;
    fleche D;
    E = SegmentToVecteur(D);
    fleche E;
    show ProduitScalaire(C,E);
endfig;
end.