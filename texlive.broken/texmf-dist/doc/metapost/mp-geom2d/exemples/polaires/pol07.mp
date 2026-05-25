input geom2d;

labeloffset := 6;
gddU:=1.5cm;

vardef r(expr t)  = 4*cos(t/3)*cos(t/3)*cos(t/3)  enddef;
vardef rp(expr t) = (r(t)*cos(t),r(t)*sin(t)) enddef;

def traceDoubleVecteur(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;



beginfig(1);
 Repere(8,8,2,4,1,1);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  drawoptions(withcolor Gainsboro);

  trace CourbeEnPolaires(r,0,3Pi,450)
    avecCrayon(1.5,Crimson);

  drawoptions(withcolor LightGoldenrod);

  pointe Point(0,0);
 Fin;
endfig;
end
