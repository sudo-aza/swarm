input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef r(expr t) = cos(2t)+cos(t)*cos(t)  enddef;
vardef rp(expr t) = (r(t)*cos(t),r(t)*sin(t)) enddef;

def traceDoubleVecteur(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;

a = arccos(1/sqrt(3));

beginfig(1);
 Repere(10,8,5,4,2,2);
 Axes; 
 Debut; 
  Graduations; Unites(1);
  drawoptions(withcolor LightBlue);

  nb = 60;
  pas = 2Pi/ nb;
  for i:=0 upto nb:
    trace (0,0) -- rp(i*pas);
  endfor;

  traceDoubleVecteur((0,0),0.5(cos(a),sin(a))) avecCrayon(1,MediumVioletRed);
  traceDoubleVecteur((0,0),0.5(-cos(a),sin(a))) avecCrayon(1,MediumVioletRed);
  traceDoubleVecteur((2,0),(0,0.5)) avecCrayon(1,MediumVioletRed);
  traceDoubleVecteur((-2,0),(0,0.5)) avecCrayon(1,MediumVioletRed);
  traceDoubleVecteur((0,1),(0.5,0)) avecCrayon(1,MediumVioletRed);
  traceDoubleVecteur((0,-1),(-0.5,0)) avecCrayon(1,MediumVioletRed);

  trace CourbeEnPolaires(r,-Pi,Pi,150) avecCrayon(1.5,DarkOliveGreen);

  pointe Point(0,0);
  pointe Point(0,1);
  pointe Point(0,-1);
  pointe Point(2,0);
  pointe Point(-2,0);

 Fin;
endfig;

end
