input geom2d;

beginfig(1);
    A = Point(0,0);
    B = Point(3,0);
    C = CercleCP(A,B);
    trace hachure(C,35,0.2,0) avecCrayon(4pt,DarkRed);
    trace C ;%avecCrayon(1pt,DarkRed);
endfig;

end