input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = 1/t + 1/(t+1) enddef;
vardef g(expr t) = 1/t + 1/(1+2*t+t**2) enddef;
vardef p(expr x) = x*(x+2)+2 enddef;

beginfig(1);

 Repere(10,10,5,5,1,1);
 Axes; 
 Debut; 
  Graduations; Unites(1);

  drawoptions(withcolor LightSlateGrey);
  trace Droite(origine,Point(1,1));
  trace Representation(p,-3,1,20);

  trace Courbe(f,g,-20,-1.1,300) avecCrayon(1.5,Teal);
  trace Courbe(f,g,-0.9,-0.1,300) avecCrayon(1.5,Teal);
  trace Courbe(f,g,0.1,20,300) avecCrayon(1.5,Teal);

  pointe Point(0,0);
  pointe Point(-1,0);
  pointe Point(-0.526,-0.140);

 Fin;
endfig;
end
