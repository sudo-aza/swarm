input geom2d;

labeloffset := 6;
gddU:=1.5cm;

vardef r(expr t)  = cos(t)*cos(t)*cos(t)-sin(t)*sin(t)*sin(t)  enddef;
vardef rp(expr t) = (r(t)*cos(t),r(t)*sin(t)) enddef;

def traceDoubleVecteur(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;

a = arccos(1/sqrt(3));

beginfig(1);

 Repere(6,6,2,4,3,3);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  drawoptions(withcolor Gainsboro);

  trace (0,0)--rp(-Pi/12);
  trace (0,0)--rp(-Pi/4);
  trace (0,0)--rp(-5Pi/12);

  traceDoubleVecteur(rp(Pi/4),(0.18,0.18)) avecCrayon(1,DarkOrchid);
  traceDoubleVecteur(rp(-Pi/4),(0.18,0.18)) avecCrayon(1,DarkOrchid);
  traceDoubleVecteur(rp(-Pi/12),(0.18,0.18)) avecCrayon(1,DarkOrchid);
  traceDoubleVecteur(rp(-5Pi/12),(0.18,0.18)) avecCrayon(1,DarkOrchid);

  trace CourbeEnPolaires(r,-Pi/2,Pi/2,150)  avecCrayon(1.5,Crimson);

  drawoptions(withcolor LightGoldenrod);

  pointe Point(0,0);
  pointe rp(-Pi/12);
  pointe rp(-Pi/4);
  pointe rp(-5Pi/12);

 Fin;
endfig;
end
