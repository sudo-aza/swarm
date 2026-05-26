input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = t*t-2*t enddef;
vardef g(expr t) = t*t + 1/(t*t) enddef;
vardef fp(expr t) = 2*t+t*t enddef;
vardef gp(expr t) = t*t enddef;

beginfig(1);

 Repere(8,10,2,1,1,1);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  drawoptions(withcolor LightSlateGrey);
  trace (3,0)--(3,2)--(-1,2)--(-1,0) dashed evenly;
  trace (1,0)--(1,6)--(0,6) dashed evenly;
  trace Courbe(fp,gp,-5,5,500);

  fleche Segment((-1,2),(-1,2)+(0.5,2)) avecCrayon(1,Crimson);
  fleche Segment((3,2),(4,2)) avecCrayon(1,Crimson);
  fleche Segment((3,2),(2,2)) avecCrayon(1,Crimson);

  trace Courbe(f,g,-10,-0.05,300) avecCrayon(1.5,DarkGoldenrod);
  trace Courbe(f,g,0.05,10,300) avecCrayon(1.5,DarkGoldenrod);

  pointe Point(0,0);
  pointe Point(-1,2);
  pointe Point(3,2);
  pointe Point(1,6);

 Fin;
endfig;
end
