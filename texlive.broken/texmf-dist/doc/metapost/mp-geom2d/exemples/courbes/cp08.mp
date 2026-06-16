input geom2d;

labeloffset := 6;
gddU:=1cm;

vardef f(expr t) = 2*sin(t) enddef;
vardef g(expr t) = 2*cos(t)*cos(t)/(2-cos(t)) enddef;
vardef h(expr t) = -t*(1+f(t)) enddef;

def traceDoubleVecteur(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;

path bicorne;
bicorne = Courbe(f,g,-Pi,Pi,200)--cycle;

beginfig(1);

 Repere(9,6,4.5,1,2,2);
 Axes; 
 Debut;
  Axes;
  Graduations; Unites(1);

  colorieAvecTransparence(bicorne,CadetBlue,0.2);

  traceDoubleVecteur((0,2),(0.5,0)) avecCrayon(1,Crimson);
  traceDoubleVecteur((0,2/3),(0.5,0)) avecCrayon(1,Crimson);
  fleche Segment((2,0),(1.6,0.4)) avecCrayon(1,Crimson);
  fleche Segment((-2,0),(-1.6,0.4)) avecCrayon(1,Crimson);

  trace bicorne avecCrayon(1.5,CadetBlue);

  pointe Point(0,0);
  pointe Point(2,0);
  pointe Point(-2,0);

 Fin;
endfig;
end
