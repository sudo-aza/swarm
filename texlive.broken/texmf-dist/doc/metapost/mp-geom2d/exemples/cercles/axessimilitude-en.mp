input geom2d;
%%% from Drawing with Metapost de Toby Thurston
labeloffset := 6;
SetPointSize(3);
SetPointColor(Yellow);
gddU:=0.65cm;
beginfig(1);
  C1 = Circle((-4,0),3);
  C2 = Circle((3,0),2);
  C3 = Circle((0,-4),1);

  T1 = ExternalCommonTangent(C1,C2);
  T2 = ExternalCommonTangent(C2,C1);
  T3 = InternalCommonTangent(C1,C2);
  T4 = InternalCommonTangent(C2,C1);
  
  T5 = ExternalCommonTangent(C2,C3);
  T6 = ExternalCommonTangent(C3,C2);
  T7 = InternalCommonTangent(C2,C3);
  T8 = InternalCommonTangent(C3,C2);
  
  T9 = ExternalCommonTangent(C1,C3);
  T10 = ExternalCommonTangent(C3,C1);
  T11 = InternalCommonTangent(C1,C3);
  T12 = InternalCommonTangent(C3,C1);

  E12 = LinesIntersection(T1,T2);
  E23 = LinesIntersection(T5,T6);
  E31 = LinesIntersection(T9,T10);
  I12 = LinesIntersection(T3,T4);
  I23 = LinesIntersection(T7,T8);
  I31 = LinesIntersection(T11,T12);
  
  path t[];
  t1 :=(gddTraceObjet T1) gddEnPlace;
  t2 := (gddTraceObjet T2) gddEnPlace;
  t3 := (-10*gddU,-10*gddU)--(-10gddU,10*gddU);
  fill buildcycle(t1, t3,reverse t2) withcolor 1.4*LightSlateGrey;
  
  t4 :=(gddTraceObjet T3) gddEnPlace;
  t5 := (gddTraceObjet T4) gddEnPlace;
  t6 := (1.5*gddU,-10*gddU)--(1.5*gddU,10*gddU);
  fill buildcycle(t4, t5,reverse t6) withcolor 1.1*LightSlateGrey;

  t7 :=(gddTraceObjet T3) gddEnPlace;
  t8 := (gddTraceObjet T4) gddEnPlace;
  t9 := (-1.5*gddU,-10*gddU)--(-1.5*gddU,10*gddU);
  fill buildcycle(t7, t8,reverse t9) withcolor 1.1*LightSlateGrey;

  drawoptions(withpen pencircle scaled 1pt withcolor LightSlateGrey);
  gddFill C1 withcolor white;
  gddFill C2 withcolor white;
  gddFill C3 withcolor white;
  gddDraw C1; gddDraw C2; gddDraw C3;
  
  drawoptions();
  gddDraw Line(Center(C1),Center(C2));
  gddDraw Line(Center(C3),Center(C2));
  gddDraw Line(Center(C1),Center(C3));

  D_E = Line(E12,E23);
  gddDraw D_E dashed evenly withcolor DarkBlue;

  E_I = Segment(E12,I31);
  gddDraw E_I dashed evenly withcolor DarkRed;
  I_E1 = Segment(I12,E31);
  gddDraw I_E1 dashed evenly withcolor DarkRed;
  I_E2 = Segment(I12,E23);
  gddDraw I_E2 dashed evenly withcolor DarkRed;


  drawoptions();
  gddDrawPoint Center(C1);
  gddDrawPoint Center(C2);
  gddDrawPoint Center(C3);
  SetPointColor(DarkBlue);
  gddDrawPoint E12;  gddDrawPoint E31; gddDrawPoint E23;
  SetPointColor(DarkRed);
  gddDrawPoint I12;  gddDrawPoint I31; gddDrawPoint I23;

  gddLabel.top(btex $E_{12}$ etex,E12);
  gddLabel.bot(btex $E_{31}$ etex,E31);
  gddLabel.bot(btex $E_{23}$ etex,E23);

  gddLabel.top(btex $I_{12}$ etex,I12);
  gddLabel.llft(btex $I_{31}$ etex,I31);
  gddLabel.lrt(btex $I_{23}$ etex,I23);


  gddLabel.top(btex $C_{1}$ etex,Center(C1));
  gddLabel.top(btex $C_{2}$ etex,Center(C2));
  gddLabel.bot(btex $C_{3}$ etex,Center(C3));

  draw textext("Axis of similitude") rotated (22) shifted (0.5[Pt(E23),Pt(E12)]
  gddInPlace +(0,3));
  Window(-10,-10,19,7);
endfig;
end.