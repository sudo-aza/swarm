input geom2d;

labeloffset := 6;
gddTaillePoint := 2;
gddCouleurPoint := Yellow;

beginfig(1);
 Repere(9,9,4,5,0.8,0.8);
 Axes; 
 Debut;
  Axes;
  Graduations; Unites(1);

  C1 = Cercle((1,1),3);
  C2 = Cercle((-1,-2),1);

  T1 = TangenteCommuneExterieure(C1,C2);
  T2 = TangenteCommuneExterieure(C2,C1);

  drawoptions(withcolor LightSlateGrey);
  trace C1;
  trace C2;

  drawoptions(withcolor Olive);
  trace T1;
  trace T2;

  drawoptions();
  pointe Point(1,1);
  pointe Point(-1,-2);

 Fin;
endfig;
end
