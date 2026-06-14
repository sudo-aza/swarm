input geom2d;

labeloffset := 6;
gddU:=1cm;

vardef f(expr t) = t*t enddef;
vardef g(expr t) = t*t*t enddef;

beginfig(1);

 Repere(8,12,2,6,1,1);
 Axes; 
 Debut; 
  Graduations; Unites(1);
  fleche Segment((0,0),(2,0)) avecCrayon(1,Crimson);
  trace Courbe(f,g,-3,3,300) avecCrayon(1.5,DarkTurquoise);
  pointe Point(0,0);

 Fin;
endfig;
end
