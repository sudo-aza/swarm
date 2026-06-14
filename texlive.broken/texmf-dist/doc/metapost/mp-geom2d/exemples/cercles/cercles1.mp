input geom2d;

labeloffset := 6;

gddTaillePoint := 3;
gddCouleurPoint := Yellow;

beginfig(1);

 Repere(9,9,4,5,0.8,0.8);
 Axes; 
 Debut;
  Graduations; 
  Unites(1);

  C1 = Cercle((1,1),3);
  C2 = Cercle((-1,-2),1);

  P1 = IntersectionCercles(C1,C2);
  P2 = IntersectionCercles(C2,C1);

  drawoptions(withcolor LightSlateGrey);
  trace C1;
  trace C2;

  drawoptions();
  pointe Point(1,1);
  pointe Point(-1,-2);
  pointe P1;
  pointe P2;
  label.urt(textext("\(P_1\)"),PtR(P1));
  label.top(textext("\(P_2\)"),PtR(P2));

 Fin;

endfig;
end
