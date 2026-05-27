input geom2d;

beginfig(1);
  A = Point(0,0);
  B = Point(3,2);
  AB = Droite(A,B);
  F_1 = Point(-1,1);
  Hyper = HyperboleFD(F_1,AB,1.5);
  O   = Centre(Hyper);
  F_2 = Foyer(Hyper,2);
  Axe = Droite(F_1,F_2);
  S_1 = Sommet(Hyper,1);
  S_2 = Sommet(Hyper,2);

  trace Axe dashed evenly;
  C = CerclePrincipale(Hyper) ;
  trace C avecCrayon(0.5,LightSlateGray) dashed evenly;
  A_1 = AsymptoteHyperbole(Hyper,1);
  A_2 = AsymptoteHyperbole(Hyper,2);
  trace A_1 dashed evenly;
  trace A_2 dashed evenly;
  
  D_1 =  Directrice(Hyper,1);
  D_2 =  Directrice(Hyper,2);
    
  trace D_1 avecCrayon(1.1,CornflowerBlue);
  trace D_2 avecCrayon(1.1,CornflowerBlue);
  trace DemiHyperbole(Hyper,1) avecCrayon(1.5,Crimson);
  trace DemiHyperbole(Hyper,2) avecCrayon(1.5,Crimson);

  marque.lft "O";
  marque.lft "S_1";
  marque.lft "S_2";
  marque.lft "F_1";
  marque.lft "F_2";
  label.lft(textext("\(\mathcal{C}\)"),Pt(PointDe(C,0.6)) gddEnPlace) withcolor LightSlateGray;
  label.top(textext("\(\mathcal{D}_1\)"),Pt(PointDe(D_1,0.47)) gddEnPlace) withcolor CornflowerBlue;
  label.top(textext("\(\mathcal{D}_2\)"),Pt(PointDe(D_2,0.46)) gddEnPlace) withcolor CornflowerBlue;
  Fenetre(-4,-7,4,4);
endfig;


end.
