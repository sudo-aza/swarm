input geom2d;
beginfig(1);
RepereMinMax(-2Pi,2Pi,-1.1,1.1,0.5,1);
Axes;
Graduations;
Debut;
trace Representation(cos,-2Pi,2Pi,100);
Fin;
endfig;
end.