input geom2d;


labeloffset := 6;
gddU:=1.2cm;

vardef f(expr t) = 2*cos(t)*cos(t)*cos(t) enddef;
vardef g(expr t) = 2*sin(t)*sin(t)*sin(t) enddef;


beginfig(1);
 Frame(8,8,4,4,1.8,1.8);
 Axis; 
 gddBegin; 
  Graduations; Units(1);
  drawoptions(withpen pencircle scaled 0.5 withcolor LightSlateGrey);
  gddDraw ((-2,-2)--(-2,2)--(2,2)--(2,-2)--cycle);

  nb  = 80;
  pas = 2*Pi/nb;
  for i=0 upto nb: gddDraw (0,2*sin(i*pas))--(2*cos(i*pas),0); endfor;

  gddArrow Segment((2,0),(1.2,0)) withPen(1,RoyalBlue);
  gddArrow Segment((-2,0),(-1.2,0)) withPen(1,RoyalBlue);
  gddArrow Segment((0,2),(0,1.2)) withPen(1,RoyalBlue);
  gddArrow Segment((0,-2),(0,-1.2)) withPen(1,RoyalBlue);

  gddDraw Curve(f,g,0,2*Pi,500) withPen(1.5,DarkOrange);

  gddDrawPoint Point(0,0);
  gddDrawPoint Point(2,0);
  gddDrawPoint Point(0,2);
  gddDrawPoint Point(0,-2);
  gddDrawPoint Point(-2,0);

 gddEnd;
endfig;
end
