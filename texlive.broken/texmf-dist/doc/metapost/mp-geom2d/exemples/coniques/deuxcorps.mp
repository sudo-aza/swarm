input geom2d;

beginfig(1);
  A = Point(0,0);
  B = Point(3,2);
  AB = Droite(A,B);
  F = Point(-1,1);
  Hyper = HyperboleFD(F,AB,1.5);
  Para = ParaboleFD(F,AB);
  H1 = Chemin(DemiHyperbole(Hyper,1));
  E = EllipseFD(F,AB,0.7);
  trace E avecCrayon(1.2,FireBrick);
  trace H1 avecCrayon(1.2,DarkSlateBlue);
  trace Para avecCrayon(1.2,SandyBrown);
  S = Sommet(Hyper,1);
  D = Droite(Foyer(E,1),Foyer(E,2));
  trace D dashed evenly;
  M = PointDe(H1,0.45);
  fleche reverse gddTraceObjet ArcEntrePoints(F,0.4,S,M,-1);
  trace Segment(F,M);
  pointe F;
  pointe M;
  gddLabel.urt(textext("$\theta$"),Addition(F,(0.4,-0.2)));
  gddLabel.lrt(textext("$M(r,\theta)$"),M);
  gddLabel.rt(textext("$e>1$"),PointDe(H1,0.41)) withcolor
  DarkSlateBlue;
  gddLabel.llft(textext("$e=1$"),PointDe(Para,0.58)) withcolor
  SandyBrown;
  gddLabel.lft(textext("$e<1$"),PointDe(E,0.58)) withcolor FireBrick;
  Fenetre(-4.5,-1.5,3,4);
endfig;
end