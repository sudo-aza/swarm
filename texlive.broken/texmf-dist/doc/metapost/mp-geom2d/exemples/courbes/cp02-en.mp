input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = sin(2*t+Pi/3) enddef;
vardef g(expr t) = sin(3*t) enddef;

beginfig(1);
 Frame(8,8,4,4,3,3);
 Axis; 
 gddBegin; 
  Graduations; Units(1);

  drawoptions(withcolor LightSlateGrey);
  gddDraw ((-1,-1)--(-1,1)--(1,1)--(1,-1)--cycle);
  gddDraw ((-1,-1)--(1,1));
  gddDraw (1,-1)--(-1,1);
  gddDraw Circle(origine,1);
  gddDraw ((-1,0.5)--(1,0.5));
  gddDraw ((-1,-0.5)--(1,-0.5));
  gddDraw ((0.5,-1)--(0.5,1));
  gddDraw ((-0.5,-1)--(-0.5,1));
  gddDraw ((-1,sqrt(3)/2)--(1,sqrt(3)/2));
  gddDraw ((-1,-sqrt(3)/2)--(1,-sqrt(3)/2));
  gddDraw ((sqrt(3)/2,-1)--(sqrt(3)/2,1));
  gddDraw ((-sqrt(3)/2,-1)--(-sqrt(3)/2,1));

  gddDraw Curve(f,g,0,2*Pi,500) withPen(1.5,Orchid);

  pointe Point(0,0);

 gddEnd;
endfig;
end
