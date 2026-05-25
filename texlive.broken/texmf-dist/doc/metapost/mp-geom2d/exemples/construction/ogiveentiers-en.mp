input geom2d;

beginfig(1);
    % base points for the ogive
    O = Point(0,0);
    A = Point(-3,0);
    A2 = Point(-4,0);
    B = Point(3,0);
    B2 = Point(4,0);
    % the base line of the ogive
    AB = Line(A,B);
    % we take an arbitrary line
    Ct = Point(0.8,-2); % arbitrary point
    AC = Line(A,Ct); % arbitrary line
    % we take three equal lengths on the line
    longueurTier := 1.4;
    C1 =  ReportOnLine(A,AC,longueurTier);
    C2 =  ReportOnLine(C1,AC,longueurTier);
    C3 =  ReportOnLine(C2,AC,longueurTier);
    % we define the line passing through B and the last point
    BC = Line(B,C3);
    % we construct a perpendicular line to BC
    D = Point(-4,0);
    perpD = PerpendicularLine(BC,D);
    DD = LinesIntersection(perpD,BC);
    % we project C2 and C1 onto the line AB to divide [AB] into 3 equal parts
    perpC2 = PerpendicularLine(perpD,C2);
    perpC1 = PerpendicularLine(perpD,C1);
    D1 = LinesIntersection(AB,perpC1);
    D2 = LinesIntersection(AB,perpC2);
    % we construct the envelope of the ogive
    C_DA = CircleCP(D2,A);
    C_DB = CircleCP(D1,B);
    C_DA2 = CircleCP(D2,A2);
    C_DB2 = CircleCP(D1,B2);
    % we construct the point P for the final projection
    C_AB = CircleCP(A,B);
    C_BA = CircleCP(B,A);
    P = CirclesIntersection(C_BA,C_AB);
    % we take 5 equal lengths on the initial arbitrary line
    longueurCinq :=0.8;
    F1 =  ReportOnLine(A,AC,longueurCinq);
    F2 =  ReportOnLine(F1,AC,longueurCinq);
    F3 =  ReportOnLine(F2,AC,longueurCinq);
    F4 =  ReportOnLine(F3,AC,longueurCinq);
    F5 =  ReportOnLine(F4,AC,longueurCinq);
    % we project the points onto AB to divide [AB] into 5 equal parts
    BF5 = Line(B,F5);
    perpF5 = PerpendicularLine(BF5,A2);
    CC = LinesIntersection(BF5,perpF5);
    perpF4 = PerpendicularLine(perpF5,F4);
    perpF3 = PerpendicularLine(perpF5,F3);
    perpF2 = PerpendicularLine(perpF5,F2);
    perpF1 = PerpendicularLine(perpF5,F1);
    G1 = LinesIntersection(AB,perpF1);
    G2 = LinesIntersection(AB,perpF2);
    G3 = LinesIntersection(AB,perpF3);
    G4 = LinesIntersection(AB,perpF4);
    % we project the Gi points onto the ogive using point P
    PG1 = Line(P,G1);
    PG2 = Line(P,G2);
    PG3 = Line(P,G3);
    PG4 = Line(P,G4);
    I1 = LineCircleIntersection(PG1,C_DA,1);
    I2 = LineCircleIntersection(PG2,C_DA,2);
    I3 = LineCircleIntersection(PG3,C_DB,2);
    I4 = LineCircleIntersection(PG4,C_DB,2);
    % from the 2 points resulting from dividing [AB] into 3 parts
    % we draw the separations of the stones that make up the ogive
    Dvoute1 = Line(D2,I1);
    Dvoute2 = Line(D2,I2);
    Dvoute3 = Line(D1,I3);
    Dvoute4 = Line(D1,I4);
 
    % drawings
    drawoptions(withcolor 1.3*Grey);
    gddDraw perpC2; gddDraw perpC1;
    gddDraw AB;
    gddDraw AC;
    gddDraw BC;
    gddDraw perpD;
    gddDraw OrthoSign(B,DD,A2,0.2);

    drawoptions(withcolor Bisque);
    gddDraw BF5;
    gddDraw perpF5;gddDraw perpF4;gddDraw perpF3;gddDraw perpF2;gddDraw perpF1;
    gddDraw OrthoSign(B,CC,A2,0.2);

    drawoptions(withcolor SteelBlue withpen pencircle scaled 0.85pt);
    gddDraw gddDrawCircleArc(C_DA,Pi/2,Pi);
    gddDraw gddDrawCircleArc(C_DA2,Pi/2,Pi);
    gddDraw gddDrawCircleArc(C_DB2,0,Pi/2);
    gddDraw gddDrawCircleArc(C_DB,0,Pi/2);

    drawoptions();
    gddDraw gddDrawCircleArc(C_AB,0,-Pi/2) dashed evenly;
    gddDraw gddDrawCircleArc(C_BA,Pi,3Pi/2) dashed evenly;
    
    drawoptions(withcolor DarkSalmon);
    gddDraw PG1; gddDraw PG2; gddDraw PG3; gddDraw PG4;
    
    drawoptions(withcolor SteelBlue withpen pencircle scaled 0.85pt);
    gddDraw Dvoute1; gddDraw Dvoute2; gddDraw Dvoute3; gddDraw Dvoute4;
    drawoptions();
   
    SetPointColor(DarkRed);
    gddDrawPoint O;
    gddDrawPoint A;
    gddDrawPoint B;    gddDrawPoint D;
    gddDrawPoint B2;

    SetPointColor(Bisque);
    gddDrawPoint F1; gddDrawPoint F2; gddDrawPoint F3; gddDrawPoint F4;
    gddDrawPoint F5; 
    gddDrawPoint G1; gddDrawPoint G2;gddDrawPoint G3;gddDrawPoint G4;
    SetPointColor(1.3*Grey);
    gddDrawPoint DD;
    gddDrawPoint C1; gddDrawPoint C2; gddDrawPoint C3; 
    gddDrawPoint D1; gddDrawPoint D2;

    SetPointColor(DarkSalmon);
    gddDrawPoint P;
    gddDrawPoint I1; gddDrawPoint I2; gddDrawPoint I3; gddDrawPoint I4;
    Window(-5,-7,5,5);
endfig;
end.

