input geom2d;
%%% depuis Drawing with Metapost de Toby Thurston
labeloffset := 6;
gddTaillePoint := 3;
gddCouleurPoint := Yellow;
gddU:=0.65cm;
beginfig(1);
  C1 = Cercle((-4,0),3);
  C2 = Cercle((3,0),2);
  C3 = Cercle((0,-4),1);

  T1 = TangenteCommuneExterieure(C1,C2);
  T2 = TangenteCommuneExterieure(C2,C1);
  T3 = TangenteCommuneInterieure(C1,C2);
  T4 = TangenteCommuneInterieure(C2,C1);
  
  T5 = TangenteCommuneExterieure(C2,C3);
  T6 = TangenteCommuneExterieure(C3,C2);
  T7 = TangenteCommuneInterieure(C2,C3);
  T8 = TangenteCommuneInterieure(C3,C2);
  
  T9 = TangenteCommuneExterieure(C1,C3);
  T10 = TangenteCommuneExterieure(C3,C1);
  T11 = TangenteCommuneInterieure(C1,C3);
  T12 = TangenteCommuneInterieure(C3,C1);

  E12 = IntersectionDroites(T1,T2);
  E23 = IntersectionDroites(T5,T6);
  E31 = IntersectionDroites(T9,T10);
  I12 = IntersectionDroites(T3,T4);
  I23 = IntersectionDroites(T7,T8);
  I31 = IntersectionDroites(T11,T12);
  
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
  colorie C1 withcolor white;
  colorie C2 withcolor white;
  colorie C3 withcolor white;
  trace C1; trace C2; trace C3;
  
  drawoptions();
  trace Droite(Centre(C1),Centre(C2));
  trace Droite(Centre(C3),Centre(C2));
  trace Droite(Centre(C1),Centre(C3));

  D_E = Droite(E12,E23);
  trace D_E dashed evenly withcolor DarkBlue;

  E_I = Segment(E12,I31);
  trace E_I dashed evenly withcolor DarkRed;
  I_E1 = Segment(I12,E31);
  trace I_E1 dashed evenly withcolor DarkRed;
  I_E2 = Segment(I12,E23);
  trace I_E2 dashed evenly withcolor DarkRed;


  drawoptions();
  pointe Centre(C1);
  pointe Centre(C2);
  pointe Centre(C3);
  gddCouleurPoint := DarkBlue;
  pointe E12;  pointe E31; pointe E23;
  gddCouleurPoint := DarkRed;
  pointe I12;  pointe I31; pointe I23;

  label.top(btex $E_{12}$ etex,PointTOPair(E12) gddEnPlace);
  label.bot(btex $E_{31}$ etex,PointTOPair(E31) gddEnPlace);
  label.bot(btex $E_{23}$ etex,PointTOPair(E23) gddEnPlace);

  label.top(btex $I_{12}$ etex,PointTOPair(I12) gddEnPlace);
  label.llft(btex $I_{31}$ etex,PointTOPair(I31) gddEnPlace);
  label.lrt(btex $I_{23}$ etex,PointTOPair(I23) gddEnPlace);


  label.top(btex $C_{1}$ etex,PointTOPair(Centre(C1)) gddEnPlace);
  label.top(btex $C_{2}$ etex,PointTOPair(Centre(C2)) gddEnPlace);
  label.bot(btex $C_{3}$ etex,PointTOPair(Centre(C3)) gddEnPlace);

  draw textext("Axe de similitude") rotated (22) shifted (0.5[Pt(E23),Pt(E12)]
  gddEnPlace +(0,3));
  Fenetre(-10,-10,19,7);
endfig;
end.