input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = t*t-2*t enddef;
vardef g(expr t) = t*t + 1/(t*t) enddef;
vardef fp(expr t) = 2*t+t*t enddef;
vardef gp(expr t) = t*t enddef;

beginfig(1);

 Frame(8,10,2,1,1,1);
 Axis; 
 gddBegin; 
  Graduations; Units(1);

  drawoptions(withcolor LightSlateGrey);
  gddDraw (3,0)--(3,2)--(-1,2)--(-1,0) dashed evenly;
  gddDraw (1,0)--(1,6)--(0,6) dashed evenly;
  gddDraw Curve(fp,gp,-5,5,500);

  gddArrow Segment((-1,2),(-1,2)+(0.5,2)) withPen(1,Crimson);
  gddArrow Segment((3,2),(4,2)) withPen(1,Crimson);
  gddArrow Segment((3,2),(2,2)) withPen(1,Crimson);

  gddDraw Curve(f,g,-10,-0.05,300) withPen(1.5,DarkGoldenrod);
  gddDraw Curve(f,g,0.05,10,300) withPen(1.5,DarkGoldenrod);

  gddDrawPoint Point(0,0);
  gddDrawPoint Point(-1,2);
  gddDrawPoint Point(3,2);
  gddDrawPoint Point(1,6);

 gddEnd;
endfig;
end
