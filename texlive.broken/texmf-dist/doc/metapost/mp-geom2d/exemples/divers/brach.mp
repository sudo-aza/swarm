input geom2d;

color darkred,darkblue;
darkred=(.6,0,0);
darkblue=(0,0,.6);

labeloffset := 6;
gddTaillePoint := 3;
gddCouleurPoint := (1,1,1);


% la cycloide
vardef f(expr t)=
  t-sin(t)
enddef;
vardef g(expr t)=
  cos(t)-1
enddef;


beginfig(1);
 Repere(6,4,1,3,1,1);
 Axes;
 Debut;
  Axes;
  Graduations; Unites(2);

  A = Point(0,0);
  B =  Point(f(3),g(3));
  C = Point(2.4,-1);
  M = Point(f(2.4),g(2.4));
  N = Point(2.4,0);
  C1 = Cercle(C,1);
  trace Arc(C,.3,Pi/2,Pi/2+2.4);
  trace Droite((2.4,0),C) dashed evenly;
  trace Courbe(f,g,0,3,500) withcolor darkred withpen pencircle scaled 1pt;
  trace Courbe(f,g,3,4.5,100) dashed evenly;
  trace Courbe(f,g,-2,0,100) dashed evenly;
  trace C1;
  trace Segment(C,M);
    trace Arc(C,1,Pi/2,Pi/2+2.4) withcolor darkblue withpen pencircle scaled .7pt;
  trace Segment(A,N) withcolor darkblue withpen pencircle scaled .7pt;

  marque.rt "C";
  marque.llft "M";
  pointe(N);
  label.urt(textext("$N$"),PtR(N));
  label.ulft(textext("$\theta$"),PtR(C)+.2*gddU*(cos(Pi/2+1.2),sin(Pi/2+1.2)));
  gddCouleurPoint := Yellow;
  marque.urt "A";
  marque.llft "B";
 Fin;
endfig;
end