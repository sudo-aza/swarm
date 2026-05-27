input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = sin(2*t+Pi/3) enddef;
vardef g(expr t) = sin(3*t) enddef;

beginfig(1);
 Repere(8,8,4,4,3,3);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  drawoptions(withcolor LightSlateGrey);
  trace ((-1,-1)--(-1,1)--(1,1)--(1,-1)--cycle);
  trace ((-1,-1)--(1,1));
  trace (1,-1)--(-1,1);
  trace Cercle(origine,1);
  trace ((-1,0.5)--(1,0.5));
  trace ((-1,-0.5)--(1,-0.5));
  trace ((0.5,-1)--(0.5,1));
  trace ((-0.5,-1)--(-0.5,1));
  trace ((-1,sqrt(3)/2)--(1,sqrt(3)/2));
  trace ((-1,-sqrt(3)/2)--(1,-sqrt(3)/2));
  trace ((sqrt(3)/2,-1)--(sqrt(3)/2,1));
  trace ((-sqrt(3)/2,-1)--(-sqrt(3)/2,1));

  trace Courbe(f,g,0,2*Pi,500) avecCrayon(1.5,Orchid);

  pointe Point(0,0);

 Fin;
endfig;
end
