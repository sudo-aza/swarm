input geom2d;

labeloffset := 6;
gddU:=1cm;

vardef f(expr t) = 2*sin(t) enddef;
vardef g(expr t) = 2*cos(t)*cos(t)/(2-cos(t)) enddef;
vardef h(expr t) = -t*(1+f(t)) enddef;

def DrawDoubleVector(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;

path bicorne;
bicorne = Curve(f,g,-Pi,Pi,200)--cycle;

beginfig(1);

 Frame(9,6,4.5,1,2,2);
 Axis; 
 gddBegin;
  Axis;
  Graduations; Units(1);

  gddAlphaFill(bicorne,CadetBlue,0.2);

  DrawDoubleVector((0,2),(0.5,0)) withPen(1,Crimson);
  DrawDoubleVector((0,2/3),(0.5,0)) withPen(1,Crimson);
  gddArrow Segment((2,0),(1.6,0.4)) withPen(1,Crimson);
  gddArrow Segment((-2,0),(-1.6,0.4)) withPen(1,Crimson);

  gddDraw bicorne withPen(1.5,CadetBlue);

  gddDrawPoint Point(0,0);
  gddDrawPoint Point(2,0);
  gddDrawPoint Point(-2,0);

 gddEnd;
endfig;
end
