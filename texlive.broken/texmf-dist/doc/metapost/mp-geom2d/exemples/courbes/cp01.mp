input geom2d;


labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = 2*cos(t)*cos(t)*cos(t) enddef;
vardef g(expr t) = 2*sin(t)*sin(t)*sin(t) enddef;


beginfig(1);
 Repere(8,8,4,4,1.8,1.8);
 Axes; 
 Debut; 
  Graduations; Unites(1);
  drawoptions(withpen pencircle scaled 0.5 withcolor LightSlateGrey);
  trace ((-2,-2)--(-2,2)--(2,2)--(2,-2)--cycle);

  nb  = 80;
  pas = 2*Pi/nb;
  for i=0 upto nb: trace (0,2*sin(i*pas))--(2*cos(i*pas),0); endfor;

  fleche Segment((2,0),(1.2,0)) avecCrayon(1,RoyalBlue);
  fleche Segment((-2,0),(-1.2,0)) avecCrayon(1,RoyalBlue);
  fleche Segment((0,2),(0,1.2)) avecCrayon(1,RoyalBlue);
  fleche Segment((0,-2),(0,-1.2)) avecCrayon(1,RoyalBlue);

  trace Courbe(f,g,0,2*Pi,500) avecCrayon(1.5,DarkOrange);

  pointe Point(0,0);
  pointe Point(2,0);
  pointe Point(0,2);
  pointe Point(0,-2);
  pointe Point(-2,0);

 Fin;
endfig;
end
