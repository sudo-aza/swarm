input geom2d;

labeloffset := 4;
gddU:=1.cm;

beginfig(1);
  O = Point(0,0);
  I = Point(1,0);
  J = Point(0.3,0.8);
  M = PointInBasis(5,3,O,I,J);
  H = PointInBasis(5,0,O,I,J);
  K = PointInBasis(0,3,O,I,J);
  O' = Point(3,2);
  I' = Point(3.7,1.8);
  J' = Point(2.8,3);

  pair Mt;
  Mt = CoordinatesInBasis(M,O',I',J');
  H' = PointInBasis(xpart Mt,0,O',I',J');
  K' = PointInBasis(0,ypart Mt,O',I',J');

  Frame(8,6,1.5,1.5,1,1);
  gddBegin;
    gddDraw Line(O,I);
    gddDraw Line(O,J);
    gddDraw Line(O',I');
    gddDraw Line(O',J');

    gddDraw Pt(K)--Pt(M)--Pt(H) dashed evenly;
    gddDraw Pt(K')--Pt(M)--Pt(H') dashed evenly;

    gddMark.urt  "M";

    drawoptions(withpen pencircle scaled 1pt withcolor DodgerBlue);
    gddArrow Segment(O,K);
    gddArrow Segment(O,H);
    gddArrow Segment(O,M);

    drawoptions(withpen pencircle scaled 1pt withcolor LimeGreen);
    gddArrow Segment(O',M);
    gddArrow Segment(O',H');
    gddArrow Segment(O',K');

    drawoptions(withpen pencircle scaled 1.5pt withcolor Crimson);
    gddArrow Segment(O,I);
    gddArrow Segment(O,J);
    gddArrow Segment(O',I');
    gddArrow Segment(O',J');

    drawoptions(withpen pencircle scaled 1pt withcolor LightCoral);
    gddArrow Segment(O,O');

    drawoptions();
    gddMark.llft "O";
    gddMark.llft "O'";

    label.bot(textext("\(x\)"), PtR(H));
    label.lft(textext("\(y\)"), PtR(K));
    label.bot(textext("\(\vec\imath\)"), PtR(I));
    label.lft(textext("\(\vec\jmath\)"), PtR(J));

    label.bot(textext("\(x'\)"), PtR(H'));
    label.urt(textext("\(y'\)"), PtR(K'));
    label.bot(textext("\(\vec\imath'\)"), PtR(I'));
    label.lft(textext("\(\vec\jmath'\)"), PtR(J'));

  gddEnd;
endfig;
end
