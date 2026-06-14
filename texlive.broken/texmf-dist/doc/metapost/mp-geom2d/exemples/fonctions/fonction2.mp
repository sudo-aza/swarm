input geom2d;

labeloffset := 6;
gddU:=0.9cm;

vardef f(expr x) = x*(Pi-x) enddef;  % f
vardef g(expr x) = Pi-2*x enddef;    % f'
vardef h(expr x) = -2 enddef;        % f''

beginfig(1);

Repere(9,6,5,3,.8,0.8);
Axes;
 Debut;
  Graduations;

  trace (Pi,-2)--(Pi,2) dashed evenly;
  trace (-Pi,-2)--(-Pi,2) dashed evenly;

  trace Representation(f,0,Pi,100) avecCrayon(1.5,Indigo);
  trace (Representation(f,0,Pi,100) scaled -1) avecCrayon(1.5,Indigo);
  trace (Representation(f,0,Pi,100) shifted (-2*Pi,0)) avecCrayon(1.5,Indigo);
  trace (Representation(f,0,Pi,100) scaled -1 shifted (2*Pi,0)) avecCrayon(1.5,Indigo);

  trace Representation(g,0,Pi,100) avecCrayon(1.5,Olive);
  trace (Representation(g,0,Pi,100) xscaled -1) avecCrayon(1.5,Olive);
  trace (Representation(g,0,Pi,100) shifted (-2*Pi,0)) avecCrayon(1.5,Olive);
  trace (Representation(g,0,Pi,100) xscaled -1 shifted (2*Pi,0)) avecCrayon(1.5,Olive);

  trace Representation(h,0,Pi,100) avecCrayon(1.5,Orange);
  trace (Representation(h,0,Pi,100) scaled -1) avecCrayon(1.5,Orange);
  trace (Representation(h,0,Pi,100) shifted (-2*Pi,0)) avecCrayon(1.5,Orange);
  trace (Representation(h,0,Pi,100) scaled -1 shifted (2*Pi,0)) avecCrayon(1.5,Orange);

  pointe Point(Pi,2);
  pointe Point(Pi,-2);
  pointe Point(-Pi,2);
  pointe Point(-Pi,-2); 

  label.urt(textext("\(-\pi\)"), (-Pi,0) gddEnPlace) withcolor Peru;
  label.ulft(textext("\(\pi\)"), (Pi,0) gddEnPlace) withcolor Peru;
Fin;

trace (0,-0.5)--(1,-0.5) avecCrayon(1.5,Indigo);
label.rt(textext("\(f\)"), (1,-0.5) gddEnPlace);
trace (2,-0.5)--(3,-0.5) avecCrayon(1.5,Olive);
label.rt(textext("\(f'\)"), (3,-0.5) gddEnPlace);
trace (4,-0.5)--(5,-0.5) avecCrayon(1.5,Orange);
label.rt(textext("\(f''\)"), (5,-0.5) gddEnPlace);

endfig;

end
