input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef r(expr t)  = sqrt(cos(2*t))  enddef;
vardef ri(expr t) = -sqrt(cos(2*t))  enddef;
vardef rh(expr t) = 1 / r(t) enddef;
vardef rhi(expr t) = 1 / ri(t) enddef;

vardef u(expr v) = sqrt(v*v+4) enddef;
vardef rp(expr t) = (r(t)*cos(t),r(t)*sin(t)) enddef;

def traceDoubleVecteur(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;

a = arccos(1/sqrt(3));

beginfig(1);
 Repere(10,6,5,3,3,3);
 Axes; 
 Debut; 
  Graduations;
  drawoptions(withcolor Gainsboro);

  nb = 40;
  pas = Pi / (2*nb);
  for i:=0 upto nb:
    trace Droite((0,0),(cos(-Pi/4+i*pas),sin(-Pi/4+i*pas)));
  endfor;

  trace Droite((0,0),(1,1));
  trace Droite((0,0),(-1,1));

  trace CourbeEnPolaires(rh,-Pi/4+0.01,Pi/4-0.01,150)
    avecCrayon(0.75,Crimson);
  trace CourbeEnPolaires(rhi,-Pi/4+0.01,Pi/4-0.01,150)
    avecCrayon(0.75,Crimson);

  traceDoubleVecteur((0,0),0.25(1,1)) avecCrayon(1,LightSalmon);
  traceDoubleVecteur((0,0),0.25(-1,1)) avecCrayon(1,LightSalmon);
  traceDoubleVecteur((1,0),(0,0.2)) avecCrayon(1,LightSalmon);
  traceDoubleVecteur((-1,0),(0,0.2)) avecCrayon(1,LightSalmon);
  traceDoubleVecteur(rp(Pi/6),(0.2,0)) avecCrayon(1,LightSalmon);
  traceDoubleVecteur(rp(-Pi/6),(0.2,0)) avecCrayon(1,LightSalmon);
  traceDoubleVecteur(rp(5Pi/6),(0.2,0)) avecCrayon(1,LightSalmon);
  traceDoubleVecteur(rp(-5Pi/6),(0.2,0)) avecCrayon(1,LightSalmon);

  trace (0,0)--CourbeEnPolaires(r,-Pi/4+0.0001,Pi/4-0.0001,150)--cycle
    avecCrayon(1.5,LightSlateGrey);
  trace (0,0)--CourbeEnPolaires(ri,-Pi/4+0.0001,Pi/4-0.0001,150)--cycle
    avecCrayon(1.5,LightSlateGrey);

  pointe Point(0,0);

 Fin;
endfig;
end
