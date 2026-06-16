input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef r(expr t) = 1+2*cos(t) enddef;
vardef rp(expr t) = (r(t)*cos(t),r(t)*sin(t)) enddef;

def traceDoubleVecteur(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;

beginfig(1);
 Repere(10,10,2.2,5,2,2);
 Axes; 
 Debut; 
  Graduations; Unites(1);
  drawoptions(withcolor LightSlateGrey);

  nb = 50;
  pas = 4 / nb;
  for i=1 upto nb:
    vardef rt(expr t) = 1 + (-1+i*pas)*cos(t) enddef;
    trace CourbeEnPolaires(rt,-Pi,Pi,100) withcolor ((i/nb)[Gainsboro,Chartreuse]);
  endfor;

  trace CourbeEnPolaires(r,-Pi,Pi,100) avecCrayon(1.5,LightSeaGreen);

  pointe Point(0,0);
  pointe Point(0,1);
  pointe Point(0,-1);

 Fin;
endfig;
end
