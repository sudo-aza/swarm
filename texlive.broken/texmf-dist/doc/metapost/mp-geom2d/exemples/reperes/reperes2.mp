input geom2d;

labeloffset := 4;
gddU:=1.cm;

beginfig(1);
  O = Point(0,0);
  I = Point(1,0);
  J = Point(0.3,0.8);
  M = PointDansRepere(5,3,O,I,J);
  H = PointDansRepere(5,0,O,I,J);
  K = PointDansRepere(0,3,O,I,J);
  O' = Point(3,2);
  I' = Point(3.7,1.8);
  J' = Point(2.8,3);

  pair Mt;
  Mt = CoordonneesRepere(M,O',I',J');
  H' = PointDansRepere(xpart Mt,0,O',I',J');
  K' = PointDansRepere(0,ypart Mt,O',I',J');

  Repere(8,6,1.5,1.5,1,1);
  Debut;
    trace Droite(O,I);
    trace Droite(O,J);
    trace Droite(O',I');
    trace Droite(O',J');

    trace Pt(K)--Pt(M)--Pt(H) dashed evenly;
    trace Pt(K')--Pt(M)--Pt(H') dashed evenly;

    marque.urt  "M";

    drawoptions(withpen pencircle scaled 1pt withcolor DodgerBlue);
    fleche Segment(O,K);
    fleche Segment(O,H);
    fleche Segment(O,M);

    drawoptions(withpen pencircle scaled 1pt withcolor LimeGreen);
    fleche Segment(O',M);
    fleche Segment(O',H');
    fleche Segment(O',K');

    drawoptions(withpen pencircle scaled 1.5pt withcolor Crimson);
    fleche Segment(O,I);
    fleche Segment(O,J);
    fleche Segment(O',I');
    fleche Segment(O',J');

    drawoptions(withpen pencircle scaled 1pt withcolor LightCoral);
    fleche Segment(O,O');

    drawoptions();
    marque.llft "O";
    marque.llft "O'";

    label.bot(textext("\(x\)"), PtR(H));
    label.lft(textext("\(y\)"), PtR(K));
    label.bot(textext("\(\vec\imath\)"), PtR(I));
    label.lft(textext("\(\vec\jmath\)"), PtR(J));

    label.bot(textext("\(x'\)"), PtR(H'));
    label.urt(textext("\(y'\)"), PtR(K'));
    label.bot(textext("\(\vec\imath'\)"), PtR(I'));
    label.lft(textext("\(\vec\jmath'\)"), PtR(J'));

  Fin;
endfig;
end
