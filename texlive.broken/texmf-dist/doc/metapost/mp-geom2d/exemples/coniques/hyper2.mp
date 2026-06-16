input geom2d;

beginfig(2);
  F1 = Point(-2,1);
  F2 = Point(2,-1);
  Hyper := HyperboleF(F1,F2,1.9);
  O   := Centre(Hyper);
  Axe := Droite(F1,F2);
  S_1 := Sommet(Hyper,1);
  S_2 := Sommet(Hyper,2);

  trace Axe dashed evenly;
  C := CerclePrincipale(Hyper) ;
  trace C avecCrayon(0.5,LightSlateGray) dashed evenly;
  A_1 := AsymptoteHyperbole(Hyper,1);
  A_2 := AsymptoteHyperbole(Hyper,2);
  trace A_1 dashed evenly;
  trace A_2 dashed evenly;
  
  D_1 :=  Directrice(Hyper,1);
  D_2 :=  Directrice(Hyper,2);
    
  trace D_1 avecCrayon(1.1,CornflowerBlue);
  trace D_2 avecCrayon(1.1,CornflowerBlue);
  trace DemiHyperbole(Hyper,1) avecCrayon(1.5,Crimson);
  trace DemiHyperbole(Hyper,2) avecCrayon(1.5,Crimson);

endfig;

end.