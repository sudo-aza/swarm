input geom2d;

labeloffset := 6;
gddU:=0.8cm;

vardef r(expr t) = 1+cos(t) enddef;
vardef rp(expr t) = (r(t)*cos(t),r(t)*sin(t)) enddef;

def DrawDoubleVector(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddInPlace enddef;

beginfig(1);
 Frame(10,10,2,5,3.5,3.5);
 Axis; 
 gddBegin; 
  Graduations; Units(1);

  drawoptions(withcolor LightSlateGrey);
  draw fullcircle shifted (0.5,0) gddInPlace withPen(1,Gold);

  nb = 80;
  pas = 2Pi / nb;
  for i=0 upto nb:
    theta := i * pas;
    draw (fullcircle scaled 2cos(theta) 
      shifted (cos(theta)*cos(theta),cos(theta)*sin(theta))) gddInPlace;
  endfor;


  DrawDoubleVector(rp(0),(0,0.3)) withPen(1,LightPink);
  DrawDoubleVector(rp(Pi/3),(0.3,0)) withPen(1,LightPink);
  DrawDoubleVector(rp(Pi/2),(0.2,0.2)) withPen(1,LightPink);
  DrawDoubleVector(rp(2Pi/3),(0,0.3)) withPen(1,LightPink);
  DrawDoubleVector(rp(-Pi/3),(0.3,0)) withPen(1,LightPink);
  DrawDoubleVector(rp(-Pi/2),(0.2,-0.2)) withPen(1,LightPink);
  DrawDoubleVector(rp(-2Pi/3),(0,0.3)) withPen(1,LightPink);

  gddArrow Segment(origine,(-0.3,0)) withPen(1,LightPink);
  gddDraw PolarCurve(r,-Pi,Pi,100) withPen(1.5,Indigo);

  gddDrawPoint Point(0,0);
  gddDrawPoint Point(2,0);
  gddDrawPoint PairTOPoint(rp(Pi/3));
  gddDrawPoint PairTOPoint(rp(-Pi/3));
  gddDrawPoint PairTOPoint(rp(2Pi/3));
  gddDrawPoint PairTOPoint(rp(-2Pi/3));
  gddDrawPoint Point(0,1);
  gddDrawPoint Point(0,-1);

  gddLabel.urt(textext("\(\mathcal{C}\)"),(1,0)) withcolor Magenta;
 gddEnd;
endfig;
end
