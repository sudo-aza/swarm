%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MCF metapost souce file example                 by Akira Yamaji  2026.05.10
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%ahangle:=1;     % output png file (600dpi)
%%ahangle:=2;     % output png file (1200dpi)
%%ahlength:=3;    % output figure(expanded)
%%ahlength:=5;    % output MOL(V2000)
%%ahlength:=6;    % output MOL(V3000)
%%ahlength:=7;    % output report
%------------------------------------------------------------------------------
input mcf2graph;  %%% it must be version 5.30
%------------------------------------------------------------------------------
fsize:=(30mm,20mm); max_blength:=4mm;
%%sw_numbering:=Atom+Bond+All;
%%sw_frame:=Atom+Mol+Fig;
%------------------------------------------------------------------------------
%%ext(defaultfont:=mpfont; defaultscale:=.3;
%%label.rt(EN&" / "&mw&" / "&fdr(7)(MW_n-scantokens(MW)),(0,0));)
%------------------------------------------------------------------------------
%%loadm("CAT=biological","MW<200","a:MW");
%%loadm("CAT=pesticide","MW>=280","MW<=300","a:EN");
%%loadm("CAT=synthetic","MW>=50","MW<=300","a:MW");
%%loadm("template_lib");                  % use template_lib.mcf
%%loadm();                                % select all
loadm("LV=0")                             % select LV=0
allm                                      % draw all
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
bye
