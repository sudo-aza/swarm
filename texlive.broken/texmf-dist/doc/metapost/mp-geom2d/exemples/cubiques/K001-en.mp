input geom2d;
gddU := 0.5cm;
labeloffset := 8pt;
gddTailleLabel := 1;

beginfig(1);
  A := Point(3.6,4.8); 
  B := Point(0,0);
  C := Point(10,0);
  T := Triangle(A,B,C);
  X_74 := Point(3.6,-4.8);
  
  C1 := CurveData("K001-1",0);
  C2 := CurveData("K001-2",1);

  CE1 := EscribedCircle(T,1);
  CE2 := EscribedCircle(T,2);
  CE3 := EscribedCircle(T,3);
  I_1 := Center(CE1);
  I_2 := Center(CE2);
  I_3 := Center(CE3); 
  CC  := CircumscribedCircle(T);
  O   := Center(CC);
  
  drawoptions(withcolor LightBlue);
  gddDraw Line(A,B);
  gddDraw Line(B,C);
  gddDraw Line(C,A);
  gddDraw Line(I_1,I_2);
  gddDraw Line(I_2,I_3);
  gddDraw Line(I_3,I_1);
  gddDraw CE1;
  gddDraw CE2;
  gddDraw CE3;
  gddDraw CC;
  colorie T withcolor LightGrey;
  drawoptions(withpen pencircle scaled 1.5);
  gddDraw T;
  drawoptions(withcolor DodgerBlue withpen pencircle scaled 1.5);
  gddDraw Line(O,A);
  gddDraw Line(X_74, Point(2.2,0));
  drawoptions(withpen pencircle scaled 2);
  gddDraw C1 withcolor FireBrick;
  gddDraw C2 withcolor FireBrick;
  drawoptions(withcolor Olive);
  gddDraw Line(A,X_74);
  gddDraw Line(B,X_74);
  gddDraw Line(C,X_74);
  drawoptions();
  gddDrawPoint A;
  gddDrawPoint B;
  gddDrawPoint C;
  gddDrawPoint I_1;
  gddDrawPoint I_2;
  gddDrawPoint I_3;
  gddDrawPoint O;
  gddDrawPoint X_74;
  
  gddMark.urt "A";
  gddMark.llft "B";
  gddMark.lrt "C";
  gddMark.rt "I_1";
  gddMark.rt "I_2";
  gddMark.lft "I_3";
  gddMark.bot "O";
  gddMark.llft "X_74";
  
  Window(-4,-13,16,15);
endfig;

end