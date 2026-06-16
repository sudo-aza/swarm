# Makefile for MetaPost documentation.  Public domain.
# Rules for the groff/troff docs are in TeX Live,
# texmf-dist/doc/metapost/base/Makefile.

RM = -rm -f
latex = latex
pdflatex = pdflatex
# texexec is no longer in TL, with the advent of lmtx;
# context --luatex should run now ConTeXt MkIV
contextpdf = context --luatex 
#contextdvi = texexec --dvi
dvips = dvips
bibtex = bibtex
mpost = mpost -tex=tex
mkindex = makeindex -c -s mpman.ist

all: pdf
pdf: mpman.pdf mpgraph.pdf mpboxes.pdf #mplibapi.pdf

mplibapi.pdf: mplibapi.tex
	mv -f mpgraph.mp mpgraph.saved
	$(contextpdf) mplibapi
	mv -f mpgraph.saved mpgraph.mp

mpboxes.pdf: mpboxes.tex mpboxes.bib mpboxes.mp
	$(mpost) mpboxes
	$(pdflatex) mpboxes
	$(bibtex) mpboxes
	$(pdflatex) mpboxes
	$(mkindex) mpboxes
	$(pdflatex) mpboxes

mpgraph.pdf: mpgraph.tex mpgraph.bib mpgraph.mp
	$(mpost) mpgraph
	$(pdflatex) mpgraph
	$(bibtex) mpgraph
	$(pdflatex) mpgraph
	$(pdflatex) mpgraph

mpman.pdf: mpman.tex mpman-app-legacy.tex mpman-app-optab.tex mpman-app-refman.tex mpman-app-numbersystems.tex mpman.bib mpman.ist mpman.mp charts.mp mpman-charts.mp
	$(mpost) mpman
	$(mpost) mpman-charts
	$(pdflatex) mpman
	$(bibtex) mpman
	$(pdflatex) mpman
	$(pdflatex) mpman
	$(mkindex) mpman
	$(pdflatex) mpman


# Install the pdf files into a TL runtime (separate repository).
install_files  = grdemo-doc.pdf grdemo.pdf
install_files += mpboxes.pdf mpgraph.pdf
install_files += mpman.pdf
#
# Clearly not a suitable destination directory for anyone else :). --karl.
tldocdir = /home/texlive/karl/Master/texmf-dist/doc/metapost/base
#
# The sources go into a subdirectory.
install_sm_files  = Makefile README TODO
install_sm_files += *.d *.sty *.map *.mp *.ms *.bib *.tex *.ist
install_sm_files += figs.1 grdemo.eps grdemo-doc.ps
tldocdir_sm = $(tldocdir)/source-manual
#
INSTALL_DATA = cp -pfv
#
install-tl:
#	$(INSTALL_DATA) $(install_files) $(tldocdir)/
	$(INSTALL_DATA) $(install_sm_files) $(tldocdir_sm)/

clean:
	$(RM) *.aux *.bbl *.blg *.dvi *.idx *.ilg *.ind *.log *.mps *.mpx *.out *.toc mpxerr.*
	$(RM) *.tui *.tuo *.tmp *-mpgraph.mp

distclean: clean
	$(RM) mp?*.pdf mp?*.ps
