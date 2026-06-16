input geom2d;

beginfig(1);
    C = Point(3,2);
    A = Point(5,1);
    B = Point(3.5,3) ;
    E = Ellipse(C,A,B);
    F = EllipseF(C,A,2.5);
    D = Centre(F);
    pointe D;
    trace E;
    trace F;
    pointe C;
    pointe A;
    pointe B;
endfig;



beginfig(2);
  F1 = Point(3,1);
  F2 = Point(1.5,0.5);
  E := EllipseF(F1,F2,1.2);
  trace E;

  bboxmargin := 1cm;
  path cadre; cadre = bbox currentpicture;

  pair M;
  M = point 3.5 of (gddTraceObjet(E)) ;
  M' = PointImp(M);

  d:=Longueur(M',F1)+Longueur(M',F2);
  show d; % Pour vérifier que l'on obtient bien 2a

  trace Segment(F1,M');
  trace Segment(F2,M');
  D := TangenteEllipse(E,M);
  trace D;

  gddTaillePoint := 1.5;
  gddCouleurPoint := Yellow;
  pointe M';
  gddCouleurPoint := Gainsboro;
  pointe F1;
  pointe F2;

  setbounds currentpicture to cadre;
endfig;


beginfig(3);
  F1 := Point(3,1);
  F2 := Point(1.5,0.5);
  E := EllipseF(F1,F2,1.2);
  trace E;

  bboxmargin := 5cm;
  path cadre; cadre = bbox currentpicture;
  numeric M;
  P = Point(1,-1);
  C1 = CercleCP(P,F1);
  trace C1;
  C2 = Cercle(F2,2*DemiGrandAxe(E));
  trace C2;
  T1 = IntersectionCercles(C1,C2);
  T2 = IntersectionCercles(C2,C1);
  if(Longueur(F1,T1)<Longueur(F1,T2)):
    U = T1;
  else:
    U = T2;
  fi
  DU = Segment(F2,U);
  pair Ip;
  Ip := (gddTraceObjet(DU)) intersectionpoint (gddTraceObjet(E));
  M = PointImp(Ip);
  trace DU;
  marque.urt "M";
  marque.urt "P";
  marque.urt "F1";
  marque.urt "F2";
  marque.urt "T1";
  marque.urt "T2";
  
  setbounds currentpicture to cadre;
endfig;
beginfig(4);
  F1 := Point(3,1);
  F2 := Point(1.5,0.5);
  E := EllipseF(F1,F2,1.2);
  trace E;
  P := Point(4,1);
  bboxmargin := 5cm;
  path cadre; cadre = bbox currentpicture;
  T1 := TangenteExterieureEllipse(E,P,1); 
  trace T1;
  T2 := TangenteExterieureEllipse(E,P,2); 
  trace T2;
  marque.urt "P";
  pointe gddB[T1];

  pointe gddB[T2];
  setbounds currentpicture to cadre;
endfig;
end.