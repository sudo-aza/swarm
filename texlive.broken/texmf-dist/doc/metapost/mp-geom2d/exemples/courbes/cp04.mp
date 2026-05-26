input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = t*t+2/t enddef;
vardef g(expr t) = t+1/t enddef;
vardef fp(expr t) = t*t enddef;
vardef gp(expr t) = t enddef;

beginfig(1);

 Repere(12,10,5,4,0.7,0.7);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  drawoptions(withcolor LightSlateGrey);
  trace Droite(Point(-4,-2),Point(4,2));
  trace (3,0)--(3,2)--(0,2) dashed evenly;
  trace (-1,0)--(-1,-2)--(0,-2) dashed evenly;
  trace Courbe(fp,gp,-4,4,500);

  fleche Segment((3,2),(5,8/3)) avecCrayon(1,DeepPink);
  fleche Segment((-1,-2),(-2.8,-2)) avecCrayon(1,DeepPink);
  fleche Segment((-1,-2),(0.8,-2)) avecCrayon(1,DeepPink);

  trace Courbe(f,g,-5,-0.1,100) avecCrayon(1.5,DarkCyan);
  trace Courbe(f,g,0.1,5,100) avecCrayon(1.5,DarkCyan);

  pointe Point(0,0);
  pointe Point(3,2);
  pointe Point(-1,-2);

 Fin;
endfig;
end
