input geom2d;
input geom2d-rep;
input geom2d-lbl;
input geom2d-tra;
input geom2d-fct;
input geom2d-plt;
input geom2d-arc;
input svgnames;

lblPreambule := "\usepackage[frenchb]{babel}"       &
                "\usepackage[garamond]{mathdesign}" &
                "\usepackage{amsmath}";

labeloffset := 4;
gddU:=1.3cm;

def avecCrayon(expr t,c) = withpen pencircle scaled t withcolor c enddef;

beginfig(1);

 Repere(10,10,5,4,3,3);
 Axes; 
 Debut; 
  Graduations;
  Axes;
  ColorieAvecTransparence(Cercle(origine,1),LightSlateGrey,0.5);
  trace Cercle(origine,1) avecCrayon(1.5,LightSlateGrey);

  trace Cercle(4/3(cosd(130),sind(130)),1/3);

  drawoptions(withcolor LightSlateGrey);
  trace Cercle((0,4/3),1/3);

  centre = Point(4/3cosd(130),4/3sind(130));
  mobile = Point(4/3cosd(130)+1/3cosd(70),4/3sind(130)+1/3sind(70));

  trace (0,0)--Pt(centre)--Pt(mobile) dashed evenly;

  trace Arc(centre,1/3,-5Pi/18,7Pi/18) avecCrayon(1,DodgerBlue);
  trace Arc(origine,1,Pi/2,13Pi/18) avecCrayon(1,DodgerBlue);
  fleche Arc(centre,1/6,-5Pi/18,7Pi/18);
  fleche Arc(origine,1/3,Pi/2,13Pi/18);

  pointe Point(0,4/3);
  pointe centre;
  pointe Point(0,0);
  pointe Point(cosd(130),sind(130));

  gddCouleurPoint := Crimson;

  pointe Point(0,1);
  pointe mobile;

  drawoptions(withcolor black);

  label.lrt(TEX("\(O\)"),PtR(origine));
  label.ulft(TEX("\(\Omega(\theta)\)"),PtR(centre));
  label.urt(TEX("\(M(\theta)\)"),PtR(mobile));
  label.top(TEX("\(\theta\)"),(1/3cos(11Pi/18),1/3sin(11Pi/18)) gddEnPlace);
  label.rt(TEX("\(3\theta\)"),PtR(Addition(centre,(1/6,0))));
  label.bot(TEX("\(N(\theta)\)"),(cos(13Pi/18),sin(13Pi/18)) gddEnPlace);
 Fin;

endfig;

end