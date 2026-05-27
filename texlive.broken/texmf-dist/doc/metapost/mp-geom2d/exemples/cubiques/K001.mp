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
  
  C1 := CourbeDat("K001-1",0);
  C2 := CourbeDat("K001-2",1);

  CE1 := CercleExinscrit(T,1);
  CE2 := CercleExinscrit(T,2);
  CE3 := CercleExinscrit(T,3);
  I_1 := Centre(CE1);
  I_2 := Centre(CE2);
  I_3 := Centre(CE3); 
  CC  := CercleCirconscrit(T);
  O   := Centre(CC);
  
  drawoptions(withcolor LightBlue);
  trace Droite(A,B);
  trace Droite(B,C);
  trace Droite(C,A);
  trace Droite(I_1,I_2);
  trace Droite(I_2,I_3);
  trace Droite(I_3,I_1);
  trace CE1;
  trace CE2;
  trace CE3;
  trace CC;
  colorie T withcolor LightGrey;
  drawoptions(withpen pencircle scaled 1.5);
  trace T;
  drawoptions(withcolor DodgerBlue withpen pencircle scaled 1.5);
  trace Droite(O,A);
  trace Droite(X_74, Point(2.2,0));
  drawoptions(withpen pencircle scaled 2);
  trace C1 withcolor FireBrick;
  trace C2 withcolor FireBrick;
  drawoptions(withcolor Olive);
  trace Droite(A,X_74);
  trace Droite(B,X_74);
  trace Droite(C,X_74);
  drawoptions();
  pointe A;
  pointe B;
  pointe C;
  pointe I_1;
  pointe I_2;
  pointe I_3;
  pointe O;
  pointe X_74;
  
  marque.urt "A";
  marque.llft "B";
  marque.lrt "C";
  marque.rt "I_1";
  marque.rt "I_2";
  marque.lft "I_3";
  marque.bot "O";
  marque.llft "X_74";
  
  Fenetre(-4,-13,16,15);
endfig;

end