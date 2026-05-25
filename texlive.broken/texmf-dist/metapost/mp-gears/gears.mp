
% référence principale : https://www.zpag.net/Machines_Simples/engrenage_droit_dent_droit.htm

% p: pas primitif
% pb : pas de base
% Z: nbr de dents
% m: module (p/pi)
% rb: rayon de base
% r: rayon primitif
% rp: rayon de pied
% rt: rayon de tête
% hauteur: m + 1.25*m


% global variables
numeric _gear_pi,_gear_cpt,_gear_unit,_spir_point_size;
numeric _g_rb[], _g_rp[],
_g_rt[],_g_r[],_g_m[],_g_Z[],_g_pb[],_g_p[],_g_hauteur[],_g_alpha[],_g_rotation[],_g_spir_nbr[];
numeric _g_trans[];
string _g_type[];
pair _g_center[],_g_spir[][]; 

vardef _curve_length(expr c)=
    save N,longueur,A,B;
    N:=500;
    pair A,B;
    longueur:=0;
    for i:=0 upto N-1:
        A:= point (i/N) of c;
        B:= point((i+1)/N) of c;
        longueur:= longueur+length(B-A);
    endfor;
    longueur
enddef;


_gear_pi := 3.1415926535897932;
_gear_unit := 0.5cm;
_gear_cpt := 0;


def getUnit=
    _gear_unit
enddef;

vardef setUnit(expr u)=
    _gear_unit := u;
enddef;

color _g_axis, _g_clavette,_g_line;
_g_axis := (0.6,0.6,0.6);
_g_clavette := (0.4,0.4,0.4);
_g_line := black;

vardef setAxisColor(expr c)=
    _g_axis := c;
enddef;

vardef setLineColor(expr c)=
    _g_line := c;
enddef;

vardef setKeyColor(expr c)=
    _g_clavette := c;
enddef;

% fonction pour calculer la rayon  
vardef _compute_radius(expr Z,m)=
    (Z*m/2)
enddef;

% calculer le rayon de base en fonction du rayon primitif
vardef _compute_rb(expr a,alpha)=
    (a*cosd(alpha))
enddef;


% construction des éléments d'un engrenage
vardef _build_gear(expr Za,m,alpha,c,ang,ty)=
    % le compteur des engrenages
    _gear_cpt := _gear_cpt+1;
    % le rayon primitif
    _g_r[_gear_cpt] := _compute_radius(Za,m);
    % l'angle de pression
    _g_alpha[_gear_cpt] := alpha;
    % nombre de dents
    _g_Z[_gear_cpt] := Za;
    % module
    _g_m[_gear_cpt] := m;
    % pas primitif
    _g_p[_gear_cpt] := m*_gear_pi;
    % centre de l'engrenage
    _g_center[_gear_cpt] := c;
    % hauteur de dents
    _g_hauteur[_gear_cpt] := 2.25m;
    % rayon de base
    _g_rb[_gear_cpt] := _g_r[_gear_cpt]*cosd(alpha);
    % rayon de pied
    _g_rp[_gear_cpt] := _g_r[_gear_cpt]-1.25*m;
    % pas de pied
    _pp[_gear_cpt] := _g_p[_gear_cpt]*cosd(alpha);
    % rotation de l'engrenage
    _g_rotation[_gear_cpt] := ang;
    % type interieur ou exterieur
    _g_type[_gear_cpt] := ty;
    % on construit les points du spirograph
    if(ty="ex"):
        _build_spirograph_points(_gear_cpt);
    fi 
    _gear_cpt
enddef;

% construction des éléments d'un engrenage
vardef _build_rack(expr Za,m,alpha,c,ang,trans)=
    % le compteur des rack
    _gear_cpt := _gear_cpt+1;
    % l'angle de pression
    _g_alpha[_gear_cpt] := alpha;
    % nombre de dents
    _g_Z[_gear_cpt] := Za;
    % module
    _g_m[_gear_cpt] := m;
    % pas primitif
    _g_p[_gear_cpt] := m*_gear_pi;
    % centre de l'engrenage
    _g_center[_gear_cpt] := c;
    % hauteur de dents
    _g_hauteur[_gear_cpt] := 2.25m;
    % rotation de l'engrenage
    _g_rotation[_gear_cpt] := ang;
    % type interieur ou exterieur
    _g_trans[_gear_cpt] := trans;
    _g_type[_gear_cpt] := "rack";
    _gear_cpt
enddef;

% fonction pour déterminer les points du engrenage de type 
% spirograph. Attention sans rotation ni translation
vardef _build_spirograph_points(expr G)=
    save theta, spi, N, pas, l, len, spi_i,prev, curr;
    pair prev,curr;
    path spi;
    % spirale d'archimède rho=a*theta
    % on veut 1 tour jusqu'au rayon 1:
    % a=1/2pi
    for i:=0 step 10 until (_g_rp[G]*360): % angle en degre
        % theta en radian
        theta := i/180*_gear_pi;
        if(i=0):
            spi := (0,0);
        else:
            spi := spi--(1/(2*_gear_pi)*theta*cosd(i),1/(2*_gear_pi)*theta*sind(i));
        fi
    endfor;
    pas := 0.4; % pas entre les points
    N := 1000;
    l := length spi;
    prev := point 0 of spi;
    len:=0;
    % le centre 
    spi_i:=0;
    _g_spir[G][spi_i]:=(0,0);

    for i:=1 upto N:
        curr := point ((i/N)*l) of spi;
        len := len+length(curr-prev);
        if(len>pas): % si on dépasse le pas on marque
            spi_i:=spi_i+1;
            _g_spir[G][spi_i]:=prev;
            % on remet à zero
            len:=0;
        fi
        prev:=curr;
    endfor;
    _g_spir_nbr[G] := spi_i;
enddef;


vardef getSpirographPointNbr(expr A)=
    _g_spir_nbr[A]
enddef;

% fonction pour avoir un point «en place» de spirograph
vardef getSpirographPoint(expr G, I)=
    if(I<=_g_spir_nbr[G]):
        (_g_spir[G][I] rotated _g_rotation[G] shifted _g_center[G] scaled _gear_unit)
    else:
        errmessage("Index of spirograph point too big.")
    fi
enddef;

vardef getPrimitiveRadius(expr G)= 
    if(_g_type[G]<>"rack"):
        _g_r[G]*_gear_unit
    else:
        errmessage("Rack has no radius parameter")
    fi
enddef;

vardef getPressureAngle(expr G)= 
    _g_alpha[G]
enddef;


vardef getModule(expr G)= 
    _g_m[G]*_gear_unit
enddef;

vardef getTeethNbr(expr G)= 
    _g_Z[G]
enddef;

vardef getPrimitivePitch(expr G)= 
    _g_p[G]*_gear_unit
enddef;


vardef getCenter(expr G)= 
    (_g_center[G] scaled _gear_unit)
enddef;

vardef getRadialPoint(expr G,t)=
    if(_g_type[G]="rack"):
        errmessage("Rack has no radial point")
    else:
        (((t*_g_r[G],0) rotated _g_rotation[G]) shifted _g_center[G] scaled _gear_unit)
    fi
enddef;

vardef getToothHeight(expr G)= 
    _g_hauteur[G]*_gear_unit
enddef;


vardef getRotation(expr G)= 
    _g_rotation[G]
enddef;


vardef getTranslation(expr G)= 
    if(_g_type[G]<>"rack"):
        errmessage("Gear has no translation parameter")
    else:
        _g_trans[G]
    fi
enddef;

vardef getBottomRadius(expr G)= 
    if(_g_type[G]<>"rack"):
        _g_rp[G]*_gear_unit
    else:
        errmessage("Rack has no radius parameter")
    fi
enddef;


vardef getTopRadius(expr G)= 
    if(_g_type[G]<>"rack"):
    (_g_rp[G]+_g_hauteur[G])*_gear_unit
    else:
        errmessage("Rack has no radius parameter")
    fi
enddef;

vardef _rotation(expr p,ang)=
    (p rotated ang)
enddef;

% fonction pour définir la dent élémentaire d'un engrenage extérieur 
vardef _build_ex_tooth(expr G)=
    save p,out,t,ir,q,c,d,A,B,arc,C,D,a;
    path p[],out,q[];
    % angle degre correspondant à l’arc p/2
    t :=  (180/_gear_pi)*(_g_p[G]/2)/(_g_r[G])/2;
    % angle en degre correspondant à une dent complete
    t2 := 180/_g_Z[G];

    % point de départ des deux développante
    p1 := _g_rb[G]*(1,0);
    p2 := _g_rb[G]*(1,0);
    
    % construction des développantes à partir de (rb,0)
    for i=0 upto 60:
        ir := i/180*_gear_pi;
        p1 := p1 ..(_g_rb[G]*(cosd(i)+ir*sind(i)),_g_rb[G]*(sind(i)-ir*cosd(i)));
        p2 := p2 .. (_g_rb[G]*(cosd(i)+ir*sind(i)),-_g_rb[G]*(sind(i)-ir*cosd(i)));
    endfor

    % on calcule l'intersection des développantes avec le cercle primitif
    path d;
    d := fullcircle scaled (2*(_g_r[G]));
    pair C,D;
    C := p1 intersectionpoint d;
    % on obtient l'angle 
    a := abs(angle(C));
    % on fait la rotation des deux développantes pour avoir l'angle
    % correspondant à la longeur p sur le cercle primitif
    p1 := p1 rotated -(a+t);
    p2 := p2 rotated (a+t);
    % si le cercle de base est plus petit que le cercle de pied on tronque 
    % les développantes
    if(_g_rb[G]<= _g_rp[G]):
        d := fullcircle scaled (2*(_g_rp[G]));
        C := p1 intersectiontimes d;
        D := p2 intersectiontimes d;
        p1 := subpath (xpart C,length p1) of p1;
        p2 := subpath (xpart D,length p2) of p2;
    fi 
    % on construit les partie du profil sur le cercle de pied
    q1 := _g_rp[G]*(cosd(-t2),sind(-t2))--_g_rp[G]*(cosd(-0.8*t2),sind(-0.8*t2)){sind(t2),cosd(t2)}..{(cosd(-t),sind(-t))}  p1;
    q2 := _g_rp[G]*(cosd(t2),sind(t2))--_g_rp[G]*(cosd(0.8*t2),sind(0.8*t2)){sind(t2),-cosd(t2)}..{(cosd(t),sind(t))}
    p2 ;
    % on assemble les partie sur le cercle de pied, les développantes, et 
    % les parties du cercle de tête
    path c;
    c := fullcircle scaled (2*(_g_rp[G]+_g_hauteur[G]));
    pair A,B;
    A := q1 intersectiontimes c;
    B := q2 intersectiontimes c;
    path arc;
    arc := subpath (8-ypart A, ypart B) of c;
    ((subpath (0, xpart A) of q1) --arc-- reverse((subpath (0, xpart B) of q2))) 
enddef;


% fonction pour définir la dent élémentaire d'un engrenage intérieur  
vardef _build_in_tooth(expr G)=
    save p,out,t,ir,q,c,d,A,B,arc,C,D,a,ra;
    path p[],out,q[];
    % angle degre correspondant à l’arc p/2
    t :=  (180/_gear_pi)*(_g_p[G]/2)/(_g_r[G])/2;
    % angle en degre correspondant à une dent complete
    t2 := 180/_g_Z[G];

    % point de départ des deux développante
    p1 := _g_rb[G]*(1,0);
    p2 := _g_rb[G]*(1,0);
    
    % construction des développantes à partir de (rb,0)
    for i=0 upto 60:
        ir := i/180*_gear_pi;
        p1 := p1 ..(_g_rb[G]*(cosd(i)+ir*sind(i)),_g_rb[G]*(sind(i)-ir*cosd(i)));
        p2 := p2 .. (_g_rb[G]*(cosd(i)+ir*sind(i)),-_g_rb[G]*(sind(i)-ir*cosd(i)));
    endfor

    % on calcule l'intersection des développantes avec le cercle primitif
    path d;
    d := fullcircle scaled (2*(_g_r[G]));
    pair C,D;
    C := p1 intersectionpoint d;
    % on obtient l'angle 
    a := abs(angle(C));
    % on fait la rotation des deux développantes pour avoir l'angle
    % correspondant à la longeur p sur le cercle primitif
    p1 := p1 rotated -(a+t);
    p2 := p2 rotated (a+t);
    % si le cercle de base est plus petit que le cercle de pied on tronque 
    % les développantes
    %%% difference %%%%%%
    %% rayon pour tronquer 
    ra := _g_r[G]-1*_g_m[G];

    d := fullcircle scaled (2*(ra));
    C := p1 intersectiontimes d;
    D := p2 intersectiontimes d;
    p1 := subpath (xpart C,length p1) of p1;
    p2 := subpath (xpart D,length p2) of p2;
    %%%%%% le reste identique à l'extérieur %%%%%%%%%% 
    % on construit les partie du profil sur le cercle de pied
    q1 := (_g_rp[G]+0.15*_g_m[G])*(cosd(-t2),sind(-t2))--(_g_rp[G]+0.15*_g_m[G])*(cosd(-0.8*t2),sind(-0.8*t2)){sind(t2),cosd(t2)}..{(cosd(-t),sind(-t))}  p1;
    q2 := (_g_rp[G]+0.15*_g_m[G])*(cosd(t2),sind(t2))--(_g_rp[G]+0.15*_g_m[G])*(cosd(0.8*t2),sind(0.8*t2)){sind(t2),-cosd(t2)}..{(cosd(t),sind(t))}
    p2 ;
    % on assemble les partie sur le cercle de pied, les développantes, et 
    % les parties du cercle de tête
    path c;
    c := fullcircle scaled (2*(_g_rp[G]+_g_hauteur[G]+0.15*_g_m[G]));
    pair A,B;
    A := q1 intersectiontimes c;
    B := q2 intersectiontimes c;
    path arc;
    arc := subpath (8-ypart A, ypart B) of c;
    ((subpath (0, xpart A) of q1) --arc-- reverse((subpath (0, xpart B) of q2))) 
enddef;

% fonction pour construire le bord denté par rotation de la dent élémentaire
vardef _build_ex_gear_path(expr G)=
    save p,ee;
    path p,ee;
    ee := _build_ex_tooth(G);
    p := ee;
    for i=1 upto _g_Z[G]-1:
        p := p-- (ee rotated (i/_g_Z[G]*360)) ;
    endfor
    ((p -- cycle) ) 
    %p
enddef;

vardef _build_in_gear_path(expr G)=
    save p,ee;
    path p,ee;
    ee := _build_in_tooth(G);
    p := ee;
    for i=1 upto _g_Z[G]-1:
        p := p-- (ee rotated (i/_g_Z[G]*360)) ;
    endfor
    ((p -- cycle) ) 
    %p
enddef;

vardef _build_rack_tooth(expr G)=
    ( (_g_p[G]/2,-1.25*_g_m[G])
    --(_g_p[G]/4+sind(_g_alpha[G])/cosd(_g_alpha[G])*1.25*_g_m[G],-1.25*_g_m[G]) 
    -- (_g_p[G]/4-sind(_g_alpha[G])/cosd(_g_alpha[G])*1.0*_g_m[G],_g_m[G])
    -- (-(_g_p[G]/4-sind(_g_alpha[G])/cosd(_g_alpha[G])*1.0*_g_m[G]),_g_m[G])
    --
    (-(_g_p[G]/4+sind(_g_alpha[G])/cosd(_g_alpha[G])*1.25*_g_m[G]),-1.25*_g_m[G])
    --(-_g_p[G]/2,-1.25*_g_m[G])) rotated 90
enddef;
% crémaillère
vardef _build_rack_path(expr G)=
    save ad, p,ee;
    path p,ee;
    ee := _build_rack_tooth(G);
    ad:=0;
    % si le nombre de dents est pair,
    if((_g_Z[G] mod 2 )= 0):
        ad := 1;
    fi
    for i:=((_g_Z[G]+ad-1)/2) downto (-(_g_Z[G]+ad-1)/2):
        if(i=((_g_Z[G]+ad-1)/2)):
            p:=(ee shifted (0,i*_g_p[G]));
        else:
            p := p--(ee shifted (0,i*_g_p[G]));
        fi
    endfor 
    p
enddef;

% simple wrapper  
vardef buildExternalGear(expr Za, m, alpha,c,ang)=
    % on construit l'engrenage engrenage
    _build_gear(Za,m,alpha,c,ang,"ex")
enddef;


% simple wrapper  
vardef buildInternalGear(expr Za, m, alpha,c,ang)=
    % on construit l'engrenage engrenage
    _build_gear(Za,m,alpha,c,ang,"in")
enddef;

% simple wrapper  
vardef buildRack(expr Za, m, alpha,c,ang,trans)=
    % on construit l'engrenage engrenage
    _build_rack(Za,m,alpha,c,ang,trans)
enddef;

% fonction qui construit deux engrenages extérieurs liés
% Zb: nombre de dents du premier engrenage
% Za: nombre de dents du deuxième engrenage
% m: module 
% alpha: angle de portée
% ang: angle en degré de rotation du premier engrenage
% rota: angle de rotation du centre du deuxième engrenage 
vardef buildExternalGearPair(expr Za,Zb, m, alpha,c,ang,rota)=
    save ct,G,rotation;
    pair out,ct;
    % on construit le premier engrenage
    G1 := _build_gear(Za,m,alpha,c,ang,"ex");
    % on calcule les coordonnées du centre du deuxième engrenange
    ct := c+((_compute_radius(Za,m)+_compute_radius(Zb,m),0) rotated rota);
    % on calcule la rotation du second engrenage
    rotation := -Za/Zb*(ang)+(Za+Zb)/Zb*rota  +180/Zb 
    ;
    % on construit le deuxième engrenage
    G2 := _build_gear(Zb,m,alpha,ct,rotation,"ex");
    (G1,G2)
enddef;

% fonction qui construit un engrenage lié à engrenage déjà existant
% G: (numeric) identificateur du premier engrenage
% Zb: nombre de dents de l'engrenage à construire
% rota: angle de rotation du centre du deuxième engrenage 
vardef buildExternalGearFor(expr G,Zb,rota)=
    save ct,rotation,Z;
    pair ct;
    if(_g_type[G]="ex"):
        ct := _g_center[G]+((_compute_radius(_g_Z[G],_g_m[G])+_compute_radius(Zb,_g_m[G]),0) rotated rota);
        rotation := -_g_Z[G]/Zb*(_g_rotation[G])+(_g_Z[G]+Zb)/Zb*rota +180/Zb  ;
        Z := _build_gear(Zb,_g_m[G],_g_alpha[G],ct,rotation,"ex");
    elseif(_g_type[G]="in"):
        ct := _g_center[G]+((_g_m[G]*(_g_Z[G]-Zb)/2,0) rotated rota);
        rotation := _g_Z[G]/Zb*(_g_rotation[G])+(_g_Z[G]+Zb)/Zb*rota ;
        Z := _build_gear(Zb,_g_m[G],_g_alpha[G],ct,rotation,"ex");
    fi
    Z
enddef;


% fonction qui construit un engrenage interne lié à engrenage externe déjà  
% existant
% G: (numeric) identificateur du premier engrenage
% Zb: nombre de dents de l'engrenage à construire
% rota: angle de rotation du centre du deuxième engrenage
vardef buildInternalGearFor(expr G,Zb,rota)=
    save ct,Z,rotation;
    pair ct;
    if(Zb<_g_Z[G]):
        errmessage("Number of tooth of the internal gear must be greater");
    elseif(_g_type[G]="in"):
        errmessage("The meshed gear must be external.");
    else:
        ct := _g_center[G]-((_compute_radius(Zb,_g_m[G])-_g_r[G],0) rotated rota);
        rotation := +_g_Z[G]/Zb*(_g_rotation[G])-(_g_Z[G]-Zb)/Zb*rota ;
        Z := _build_gear(Zb,_g_m[G],_g_alpha[G],ct,rotation,"in");
    fi
    Z
enddef;


% fonction qui construit deux engrenages liés
% un est à l'intérieur de l'autre
% Zb: nombre de dents du premier engrenage
% Za: nombre de dents du deuxième engrenage
% m: module 
% alpha: angle de portée
% ang: angle en degré de rotation du premier engrenage
% rota: angle de rotation du centre du deuxième engrenage 
vardef buildInternalGearPair(expr Za,Zb, m, alpha,c,ang,rota)=
    save ct,G,rotation;
    pair ct;
    % on construit le premier engrenage
    % à l'intérieur duquel va être l'autre
    G1 := _build_gear(Za,m,alpha,c,ang,"in");
    % on calcule les coordonnées du centre du deuxième engrenange   
    ct := c+((m*(Za-Zb)/2,0) rotated rota);
    % on calcule la rotation du second engrenage
    rotation := Za/Zb*(ang)-(Za-Zb)/Zb*rota;
    % on construit le deuxième engrenage
    G2 := _build_gear(Zb,m,alpha,ct,rotation,"ex");
    (G1,G2)
enddef;



% création d'un engrenage sur le même axe et la même rotation.
% Solidaire à un précédent
vardef buildCompoundGear(expr G, Zb, m,alpha)=
    _build_gear(Zb,m,alpha,_g_center[G],_g_rotation[G],"ex")
enddef;


% fonction qui construit un engrenage et crémaillère liés
% Zb: nombre de dents du premier engrenage 
% Za: nombre de dents de la crémaillère
% m: module 
% alpha: angle de portée
% ang: angle en degré de rotation de l'engrenage
% rota: angle de rotation du centre de la crémaillère 
vardef buildGearRackPair(expr Za,Zb, m, alpha,c,ang,rota)=
    save ct,G,rotation,trans,R,t,d,p;
    pair ct;
    R := _compute_radius(Za,m);
    % on construit le premier engrenage
    G1 := _build_gear(Za,m,alpha,c,ang,"ex");
    % on calcule les coordonnées du centre du deuxième engrenange
    ct := c+((R,0) rotated rota);
    % on calcule la rotation du second engrenage
    rotation := rota;
    % distance parcouru avec rota sur le cercle primitif
    d := (_gear_pi*rota/180)*R;
    p := _gear_pi*m;
    % nombre de dents pour recentrer la crémaillère par rapport à la rotation de
    % centre 
    t:=floor(d/p);
    trans := _gear_pi*(ang)/180*R-(d-t*p)+_gear_pi*m/2;
    % on construit le deuxième engrenage
    G2 := _build_rack(Zb,m,alpha,ct,rotation,trans);
    (G1,G2)
enddef;


% fonction qui construit une crémaillère liée à un engrenage existant
% G: identifiant de l'engrenage  
% Zb: nombre de dents de la crémaillère
% rota: angle de rotation du centre de la crémaillère 
vardef buildRackFor(expr G,Zb,rota)=
    save ct,rotation,trans,R,t,d,p;
    pair ct;
    R := _g_r[G];
    % on calcule les coordonnées du centre du deuxième engrenange
    ct := _g_center[G]+((R,0) rotated rota);
    % on calcule la rotation du second engrenage
    rotation := rota;
    % distance parcouru avec rota sur le cercle primitif
    d := (_gear_pi*rota/180)*R;
    p := _gear_pi*_g_m[G];
    % nombre de dents pour recentrer la crémaillère par rapport à la rotation de
    % centre 
    t:=floor(d/p);
    trans := _gear_pi*(_g_rotation[G])/180*R-(d-t*p)+_gear_pi*_g_m[G]/2;
    % on construit le deuxième engrenage
    _build_rack(Zb,_g_m[G],_g_alpha[G],ct,rotation,trans)
enddef;


_spir_point_size := 0.15;

vardef setSpirographPointSize(expr s)=
    _spir_point_size := s;
enddef;

def getSpirographPointSize=
    _spir_point_size 
enddef;

% fonction pour dessiner un engrenage
vardef drawGear(expr G, c, typ) text p=
    save teeth,axe,entre,im,R,trou,l,spi,theta,N,pas,prev,curr, len,shape,cc;
    path teeth,axe,entre,trou,spi,shape;
    pair prev,curr;
    boolean cc;
    %booléen pour colorier ou non
    if(string c):
        cc:=false;
    else:
        cc:=true;
    fi
    picture im;
    if(_g_type[G] = "ex"):
        teeth := _build_ex_gear_path(G) scaled _gear_unit;
        if(typ="classical"):
            axe := fullcircle scaled (0.3*2*_g_r[G]) scaled _gear_unit;
            entre := (unitsquare shifted (-0.5,-0.5) xscaled (0.08*_g_r[G]) yscaled (0.1*_g_r[G])) shifted
            (0.3*(_g_r[G],0)) scaled _gear_unit;
            im := image(  
                if cc: fill teeth withcolor c; fi
                draw teeth withcolor _g_line;
                if cc: fill axe withcolor _g_axis; fi
                draw axe withcolor _g_line;
                if cc: fill entre withcolor _g_clavette; else: unfill entre; fi
                draw entre withcolor _g_line;
            );
        elseif(typ="clockwork"):
            % si le rayon est suffisamment grand par rapport au module
            if(_g_r[G]>3*_g_hauteur[G]):
                R1 := 0.2*_g_r[G];
                R2 := _g_r[G]-3*_g_m[G];
                trou :=
                ((R1,0.3*R1)--(R2,0.3*R1){-0.05,1}..(0.3*R1,R2)--(0.3*R1,R1){1,-0.3}..cycle) scaled
                _gear_unit;
                im := image(
                    l := length teeth;
                    if cc: fill teeth -- ((R2,0) scaled _gear_unit)-- reverse trou -- (0,0) -- reverse (trou rotated
                    90) -- (0,0) --
                    reverse (trou rotated 180) -- (0,0) -- reverse (trou rotated
                    270)-- (0,0)-- ((R2,0) scaled _gear_unit) --  cycle
                    withcolor c; fi
                    draw teeth withcolor _g_line;
                    draw trou withcolor _g_line;
                    draw trou rotated 90 withcolor _g_line;
                    draw trou rotated 180 withcolor _g_line;
                    draw trou rotated 270 withcolor _g_line;
                    draw fullcircle scaled ((2*0.6*R1)*_gear_unit) withcolor _g_line;
                    draw ((-0.6*R1,0)--(0.6*R1,0)) scaled _gear_unit withcolor _g_line;
                );

            else:
                R1 := 0.2*_g_r[G];
                im:=image(
                    if cc: fill teeth withcolor c;fi
                    draw teeth withcolor _g_line;
                    draw fullcircle scaled ((2*0.6*R1)*_gear_unit) withcolor _g_line;
                    draw ((-0.6*R1,0)--(0.6*R1,0)) scaled _gear_unit withcolor _g_line;
                );   
            fi
        elseif(typ="spirograph"):
            axe := fullcircle scaled (0.3*2*_g_r[G]) scaled _gear_unit;
            entre := (unitsquare shifted (-0.5,-0.5) xscaled (0.08*_g_r[G]) yscaled (0.1*_g_r[G])) shifted
            (0.3*(_g_r[G],0)) scaled _gear_unit;
            im := image(  
                if cc: fill teeth withcolor c;fi
                draw teeth withcolor _g_line;
                for i:=0 upto _g_spir_nbr[G]:
                    if cc: fill fullcircle scaled (_spir_point_size*_gear_unit) shifted
                    (_g_spir[G][i] scaled _gear_unit) withcolor background; fi
                    draw fullcircle scaled (_spir_point_size*_gear_unit) shifted
                    (_g_spir[G][i] scaled _gear_unit) withcolor _g_line;
                endfor;
            );
        else:
            errmessage("This type of drawing does not exist.")
        fi
    elseif(_g_type[G]="in"):
        if(typ="classical"):
            axe := fullcircle scaled (2*(_g_r[G]+2.5*_g_m[G])) scaled _gear_unit;
            teeth := _build_in_gear_path(G) scaled _gear_unit;
            im := image(
                if cc: fill axe-- reverse teeth--cycle withcolor c; fi
                draw teeth withcolor _g_line;
                draw axe withcolor _g_line;
            );
        else:
            errmessage("This type of drawing does not exist.");
        fi
    fi
    draw im  rotated _g_rotation[G] shifted (_g_center[G] scaled _gear_unit)  p;    
enddef;

vardef drawRack(expr G,c) text p=
    save teeth, shape,im,cc;
    path teeth, shape;
    picture im;
    boolean cc;
    %booléen pour colorier ou non
    if(string c):
        cc:=false;
    else:
        cc:=true;
    fi

    
    teeth := _build_rack_path(G);
    shape := ((point 0 of teeth)+(0.6*_g_hauteur[G],0))--teeth -- ((point
    (length teeth) of teeth)+(0.6*_g_hauteur[G],0))--cycle;
    im := image(
        if cc: fill (shape scaled _gear_unit) withcolor c; fi
        draw (shape scaled _gear_unit) withcolor _g_line;
    );
    draw im shifted (0,_g_trans[G]*_gear_unit) rotated _g_rotation[G] shifted
    (_g_center[G] scaled _gear_unit ) p;
enddef;


vardef primitiveCircle(expr G)=
    if(_g_type[G]<>"rack"):
        fullcircle scaled (2*_g_r[G]) shifted _g_center[G] scaled _gear_unit
    else:
        errmessage("Rack does not have circle parameters.");
    fi
enddef;


vardef baseCircle(expr G)=

    if(_g_type[G]<>"rack"):
        fullcircle scaled (2*_g_rb[G]) scaled _gear_unit
    else:
        errmessage("Rack does not have circle parameters.");
    fi

enddef;


vardef bottomCircle(expr G)=
    
    if(_g_type[G]<>"rack"):
        fullcircle scaled (2*_g_rp[G]) scaled _gear_unit
    else:
        errmessage("Rack does not have circle parameters.");
    fi

enddef;


vardef topCircle(expr G)=

    if(_g_type[G]<>"rack"):
        fullcircle scaled (2*(_g_rp[G]+_g_hauteur[G])) scaled _gear_unit
    else:
        errmessage("Rack does not have circle parameters.");
    fi

enddef;

vardef primitiveLine(expr G)=

    if(_g_type[G]<>"rack"):
        errmessage("Gear does not have line parameters.");
    else:
       ((0,(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)--(0,-(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)) shifted (0,_g_trans[G]*_gear_unit)
       rotated _g_rotation[G] shifted (_g_center[G] scaled  _gear_unit) 
    fi
enddef;

vardef baseLine(expr G)=

    if(_g_type[G]<>"rack"):
        errmessage("Gear does not have line parameters.");
    else:
       ((_g_m[G]*_gear_unit,(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)--(_g_m[G]*_gear_unit,-(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)) shifted (0,_g_trans[G]*_gear_unit)
       rotated _g_rotation[G] shifted (_g_center[G] scaled  _gear_unit) 
    fi
enddef;



vardef bottomLine(expr G)=

    if(_g_type[G]<>"rack"):
        errmessage("Gear does not have line parameters.");
    else:
       ((1.25*_g_m[G]*_gear_unit,(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)--(1.25*_g_m[G]*_gear_unit,-(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)) shifted (0,_g_trans[G]*_gear_unit)
       rotated _g_rotation[G] shifted (_g_center[G] scaled  _gear_unit) 
    fi
enddef;


vardef topLine(expr G)=

    if(_g_type[G]<>"rack"):
        errmessage("Gear does not have line parameters.");
    else:
       ((-_g_m[G]*_gear_unit,(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)--(-_g_m[G]*_gear_unit,-(_g_Z[G]/2+1)*_g_p[G]*_gear_unit)) shifted (0,_g_trans[G]*_gear_unit)
       rotated _g_rotation[G] shifted (_g_center[G] scaled  _gear_unit) 
    fi
enddef;





vardef spirographCurve(expr A,B,I,ang)=
    save spir,G,ct,Z,rota,S;
    path spir;
    numeric rota[];
    pair ct[],S;
    ct1 := _g_center[A]; % centre du «repere»
    % le point considéré
    spir := _g_spir[B][I] rotated (_g_rotation[B]) shifted _g_center[B];
    rota3 := 0;
    for i:=1 step 2 until ang:
        % rotation de cB par rapport à cA
        rota1 := i;
        ct2 := _g_center[B] shifted (-ct1) rotated rota1 shifted ct1;
        if(_g_type[A]="in"):
            rota2 := -(_g_Z[A]-_g_Z[B])/_g_Z[B]*rota1; %
        elseif(_g_type[A]="ex"):
            rota2 := (_g_Z[A]+_g_Z[B])/_g_Z[B]*rota1; %
        fi
        S := _g_spir[B][I] rotated (_g_rotation[B]+rota2) shifted ct2;
        spir := spir --S;
    endfor;
    (spir shifted ct1 scaled _gear_unit)
enddef;

vardef cycloidCurve(expr A,B,ang)=
    save cyc,G,ct,Z,rota,S;
    path cyc;
    numeric rota[];
    pair ct[],S;
    ct1 := _g_center[A]; % centre du «repere»
    % le point considéré
    cyc := ((_g_r[B],0)) rotated (_g_rotation[B]) shifted _g_center[B];
    for i:=2 step 2 until ang:
        % rotation de cB par rapport à cA
        rota1 := i;
        ct2 := _g_center[B] shifted (-ct1) rotated rota1 shifted ct1;
        if(_g_type[A]="in"):
            rota2 := -(_g_Z[A]-_g_Z[B])/_g_Z[B]*rota1; %
        elseif(_g_type[A]="ex"):
            rota2 := (_g_Z[A]+_g_Z[B])/_g_Z[B]*rota1; %
        fi
        S := ((_g_r[B],0) rotated (_g_rotation[B]+rota2)) shifted ct2;
        cyc := cyc--S;
    endfor;
    (cyc shifted ct1 scaled _gear_unit)
enddef;

