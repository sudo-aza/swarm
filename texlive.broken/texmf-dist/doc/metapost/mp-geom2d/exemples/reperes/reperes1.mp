input geom2d;

labeloffset := 4;
gddU:=1.3cm;

beginfig(1);


  O = Point(0,0);
  I = Point(1,0);
  J = Point(0.3,0.8);
  M = PointDansRepere(5,3,O,I,J);
  H = PointDansRepere(5,0,O,I,J);
  K = PointDansRepere(0,3,O,I,J);

  Repere(8,6,1.5,1.5,1,1);
  Debut;

    trace Droite(O,I);
    trace Droite(O,J);
    trace Pt(K)--Pt(M)--Pt(H) dashed evenly;

    marque.urt  "M";

    drawoptions(withpen pencircle scaled 1pt withcolor DodgerBlue);
    trace Vecteur(O,K);
    trace Vecteur(O,H);
    trace Vecteur(O,M);
    label.top(textext("$x\vec\imath$"),PtR(Milieu(O,H)));
    label.rt(textext("$y\vec\jmath$"),PtR(Milieu(O,K)));

    drawoptions(withpen pencircle scaled 1.5pt withcolor Crimson);
    trace Vecteur(O,I);
    trace Vecteur(O,J);

    drawoptions();
    marque.llft "O";

    label.bot(textext("$x$"), PtR(H));
    label.lft(textext("$y$"), PtR(K));
    label.bot(textext("$\vec\imath$"), PtR(I));
    label.lft(textext("$\vec\jmath$"), PtR(J));

  Fin;


endfig;

end
