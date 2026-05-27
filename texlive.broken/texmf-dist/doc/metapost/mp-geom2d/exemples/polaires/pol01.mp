input geom2d;

labeloffset := 6;
gddU:=1.2cm;

vardef r(expr t) = 1/(cos(t)-cos(2*t)) enddef;
vardef rp(expr t) = (r(t)*cos(t),r(t)*sin(t)) enddef;
vardef f(expr t) = 3/2*t*t-7/18 enddef;

def DroiteN(expr r, t) = Droite((r*cos(t),r*sin(t)), (r*cos(t)-2*sin(t),r*sin(t)+2*cos(t))) enddef;
def traceDoubleVecteur(expr o,d)= drawdblarrow ((o-d)--(o+d)) gddEnPlace enddef;

def Crayon(expr t,c) = drawoptions(withpen pencircle scaled t withcolor c) enddef;

beginfig(1);
Repere(10,10,2,5,3.5,3.5);
Axes; 
  Debut; 
    Graduations; Unites(1);
    trace Cercle(origine,1);
    Crayon(0.75,1.1*LightSlateGrey);
    trace rp(-arccos(1/4))--(0,0)--rp(arccos(1/4)) dashed evenly;
    Crayon(0.75,1.1*FireBrick);
    trace DroiteN(-2/3/sqrt(3),7*Pi/6);
    trace DroiteN(-2/3/sqrt(3),5*Pi/6);
    trace Representation(f,-3,3,100) rotated -90;
    Crayon(1.5,0.8*LightSlateGrey);
    trace CourbeEnPolaires(r,0.1,2*Pi/3-0.1,100);
    trace CourbeEnPolaires(r,-0.1,-2*Pi/3+0.1,100);
    trace CourbeEnPolaires(r,2*Pi/3+0.1,4*Pi/3-0.1,100);
    Crayon(1,DodgerBlue);
    traceDoubleVecteur(rp(Pi),(0,0.2));
    traceDoubleVecteur(rp(arccos(1/4)),0.05*(-sqrt(15),1));
    traceDoubleVecteur(rp(-arccos(1/4)),0.05*(sqrt(15),1));
    pointe rp(Pi);
    pointe rp(arccos(1/4));
    pointe rp(-arccos(1/4));
  Fin;
endfig;
end
