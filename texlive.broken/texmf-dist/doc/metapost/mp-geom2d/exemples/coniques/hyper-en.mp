input geom2d;

beginfig(1);
  A = Point(0,0);
  B = Point(3,2);
  AB = Line(A,B);
  F_1 = Point(-1,1);
  Hyper = HyperbolaFD(F_1,AB,1.5);
  O   = Center(Hyper);
  F_2 = Focus(Hyper,2);
  Axe = Line(F_1,F_2);
  S_1 = Sommet(Hyper,1);
  S_2 = Sommet(Hyper,2);

  gddDraw Axe dashed evenly;
  C = PrincipalCircle(Hyper) ;
  gddDraw C withPen(0.5,LightSlateGray) dashed evenly;
  A_1 = HyperbolaAsymptote(Hyper,1);
  A_2 = HyperbolaAsymptote(Hyper,2);
  gddDraw A_1 dashed evenly;
  gddDraw A_2 dashed evenly;
  
  D_1 =  Directrix(Hyper,1);
  D_2 =  Directrix(Hyper,2);
    
  gddDraw D_1 withPen(1.1,CornflowerBlue);
  gddDraw D_2 withPen(1.1,CornflowerBlue);
  gddDraw SemiHyperbola(Hyper,1) withPen(1.5,Crimson);
  gddDraw SemiHyperbola(Hyper,2) withPen(1.5,Crimson);

  gddMark.lft "O";
  gddMark.lft "S_1";
  gddMark.lft "S_2";
  gddMark.lft "F_1";
  gddMark.lft "F_2";
  gddLabel.lft(textext("\(\mathcal{C}\)"),PointDe(C,0.6)) withcolor LightSlateGray;
  gddLabel.top(textext("\(\mathcal{D}_1\)"),PointDe(D_1,0.47)) withcolor CornflowerBlue;
  gddLabel.top(textext("\(\mathcal{D}_2\)"),PointDe(D_2,0.46)) withcolor CornflowerBlue;
  Window(-4,-7,4,4);
endfig;


end.
