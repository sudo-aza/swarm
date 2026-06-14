input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = t/sqrt(1+t*t) enddef;
vardef g(expr t) = t*(1+f(t)) enddef;
vardef h(expr t) = -t*(1+f(t)) enddef;

beginfig(1);

 Repere(6,10,3,5,2,2);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  trace Droite((1,-2),(1,2)) withcolor MidnightBlue;

  trace (-1,0)..Courbe(f,g,-18,18,200) avecCrayon(1.5,DarkSalmon);
  trace (-1,0)..Courbe(f,h,-18,18,200) avecCrayon(1.5,DarkSalmon);

  pointe Point(0,0);

 Fin;
endfig;
end
