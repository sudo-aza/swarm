input geom2d;

beginfig(1);
    % les points de base pour l'ogive
    O = Point(0,0);
    A = Point(-3,0);
    A2 = Point(-4,0);
    B = Point(3,0);
    B2 = Point(4,0);
    % la droite de base de l'ogive
    AB = Droite(A,B);
    % on se prend une droite quelconque
    Ct = Point(0.8,-2); % point quelconque
    AC = Droite(A,Ct); % droite quelconque
    % on prend trois longueures égales sur la droite
    longueurTier := 1.4;
    C1 = ReportSurDroite(A,AC,longueurTier);
    C2 = ReportSurDroite(C1,AC,longueurTier);
    C3 = ReportSurDroite(C2,AC,longueurTier);
    % on définit la droite qui passe par B et le dernier point
    BC = Droite(B,C3);
    % on construit une droite perpendiculaire à BC
    D = Point(-4,0);
    perpD = DroitePerpendiculaire(BC,D);
    DD = IntersectionDroites(perpD,BC);
    % on projette C2 et C1 sar la droite AB pour diviser [AB] en 3 parties 
    % égales
    perpC2 = DroitePerpendiculaire(perpD,C2);
    perpC1 = DroitePerpendiculaire(perpD,C1);
    D1 = IntersectionDroites(AB,perpC1);
    D2 = IntersectionDroites(AB,perpC2);
    % on construit l'enveloppe de l'ogive 
    C_DA = CercleCP(D2,A);
    C_DB = CercleCP(D1,B);
    C_DA2 = CercleCP(D2,A2);
    C_DB2 = CercleCP(D1,B2);
    % on construit le point P pour la projection finale
    C_AB = CercleCP(A,B);
    C_BA = CercleCP(B,A);
    P = IntersectionCercles(C_BA,C_AB);
    % on prend 5 longueures égales sur la droite quelconque du début
    longueurCinq :=0.8;
    F1 = ReportSurDroite(A,AC,longueurCinq);
    F2 = ReportSurDroite(F1,AC,longueurCinq);
    F3 = ReportSurDroite(F2,AC,longueurCinq);
    F4 = ReportSurDroite(F3,AC,longueurCinq);
    F5 = ReportSurDroite(F4,AC,longueurCinq);
    % on projette les points sur AB pour diviser [AB] en 5 parties égale 
    BF5 = Droite(B,F5);
    perpF5 = DroitePerpendiculaire(BF5,A2);
    CC = IntersectionDroites(BF5,perpF5);
    perpF4 = DroitePerpendiculaire(perpF5,F4);
    perpF3 = DroitePerpendiculaire(perpF5,F3);
    perpF2 = DroitePerpendiculaire(perpF5,F2);
    perpF1 = DroitePerpendiculaire(perpF5,F1);
    G1 = IntersectionDroites(AB,perpF1);
    G2 = IntersectionDroites(AB,perpF2);
    G3 = IntersectionDroites(AB,perpF3);
    G4 = IntersectionDroites(AB,perpF4);
    % on projette les Gi sur l'ogive avec le point P
    PG1 = Droite(P,G1);
    PG2 = Droite(P,G2);
    PG3 = Droite(P,G3);
    PG4 = Droite(P,G4);
    I1 = IntersectionDroiteCercle(PG1,C_DA,1);
    I2 = IntersectionDroiteCercle(PG2,C_DA,2);
    I3 = IntersectionDroiteCercle(PG3,C_DB,2);
    I4 = IntersectionDroiteCercle(PG4,C_DB,2);
    % à partir des 2 points issus de la division en 3 de [AB]
    % on trace les séparations des pierres qui constituent l'ogive
    Dvoute1 = Droite(D2,I1);
    Dvoute2 = Droite(D2,I2);
    Dvoute3 = Droite(D1,I3);
    Dvoute4 = Droite(D1,I4);
 
    % les tracés
    drawoptions(withcolor 1.3*Grey);
    trace perpC2; trace perpC1;
    trace AB;
    trace AC;
    trace BC;
    trace perpD;
    trace SigneOrtho(B,DD,A2,0.2);

    drawoptions(withcolor Bisque);
    trace BF5;
    trace perpF5;trace perpF4;trace perpF3;trace perpF2;trace perpF1;
    trace SigneOrtho(B,CC,A2,0.2);

    drawoptions(withcolor SteelBlue withpen pencircle scaled 0.85pt);
    trace gddTraceArcDeCercle(C_DA,Pi/2,Pi);
    trace gddTraceArcDeCercle(C_DA2,Pi/2,Pi);
    trace gddTraceArcDeCercle(C_DB2,0,Pi/2);
    trace gddTraceArcDeCercle(C_DB,0,Pi/2);

    drawoptions();
    trace gddTraceArcDeCercle(C_AB,0,-Pi/2) dashed evenly;
    trace gddTraceArcDeCercle(C_BA,Pi,3Pi/2) dashed evenly;
    
    drawoptions(withcolor DarkSalmon);
    trace PG1; trace PG2; trace PG3; trace PG4;
    
    drawoptions(withcolor SteelBlue withpen pencircle scaled 0.85pt);
    trace Dvoute1; trace Dvoute2; trace Dvoute3; trace Dvoute4;
    drawoptions();
   
    gddCouleurPoint := DarkRed;
    pointe O;
    pointe A;
    pointe B;    pointe D;
    pointe B2;

    gddCouleurPoint := Bisque;
    pointe F1; pointe F2; pointe F3; pointe F4; pointe F5;
    pointe G1; pointe G2;pointe G3;pointe G4;
    gddCouleurPoint := 1.3*Grey;
    pointe DD;
    pointe C1; pointe C2; pointe C3; 
    pointe D1; pointe D2;

    gddCouleurPoint := DarkSalmon;
    pointe P;
    pointe I1; pointe I2; pointe I3; pointe I4;
    Fenetre(-5,-7,5,5);
endfig;
end.
