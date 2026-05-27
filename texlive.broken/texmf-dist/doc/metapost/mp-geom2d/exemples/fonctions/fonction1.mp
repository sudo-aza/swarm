input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr x) = sqrt(x+3-4*sqrt(x-1))+sqrt(x+8-6*sqrt(x-1)) enddef;


beginfig(1);

Repere(10,6,1,2,.8,0.8);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  trace Representation(f,1,12,100) avecCrayon(1.5,Indigo);

  pointe Point(5,1);
  pointe Point(10,1);

  label.top(textext("\(y=\sqrt{x+3-4\sqrt{x-1}}+\sqrt{x+8-6\sqrt{x-1}}\)"),
     (7,2.5) gddEnPlace) withcolor Olive;
 Fin;
endfig;
end
