input geom2d;
warningcheck:=0;
angleArbre = Pi/5;

vardef PythagorasTree(expr A,B,n)=
    save C,D,E;
    numeric C,D,E;
    D = CenterSimilarity(A,B,-Pi/2,1);
    C = CenterSimilarity(B,A,Pi/2,1);
    gddAlphaFill(Polygone(A,B,C,D), DarkBlue,0.4);
    if(n>0):
        E = CenterSimilarity(C,D,angleArbre,cos(angleArbre));
        PythagorasTree(D,E,n-1);
        PythagorasTree(E,C,n-1);
    fi
enddef;

beginfig(1);

A = Point(0,0);
B = Point(1,0);

PythagorasTree(A,B,10);

endfig;
end.