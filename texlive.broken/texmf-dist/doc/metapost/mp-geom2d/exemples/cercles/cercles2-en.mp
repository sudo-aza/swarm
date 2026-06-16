input geom2d;

labeloffset := 6;
SetPointSize(2);
SetPointColor(Yellow);

beginfig(1);
 Frame(9,9,4,5,0.8,0.8);
 Axis; 
 gddBegin;
    Axis;
    Graduations;
    Units(1);

    C1 = Circle((1,1),3);
    C2 = Circle((-1,-2),1);

    T1 = ExternalCommonTangent(C1,C2);
    T2 = ExternalCommonTangent(C2,C1);

    drawoptions(withcolor LightSlateGrey);
    gddDraw C1;
    gddDraw C2;
    
    drawoptions(withcolor Olive);
    gddDraw T1;
    gddDraw T2;
    gddDraw Xaxis;

    drawoptions();
    gddDrawPoint Point(1,1);
    gddDrawPoint Point(-1,-2);
 gddEnd;
endfig;
end
