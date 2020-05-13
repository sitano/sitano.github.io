#!/bin/sh
#thanks to https://tex.stackexchange.com/questions/11866/compile-a-latex-document-into-a-png-image-thats-as-short-as-possible
find . -name 'p_polygraph_*.tex' -exec pdflatex --output-format pdf {} \;
find . -name 'p_polygraph_*.pdf' -exec pdfcrop {} \;
find . -name 'p_polygraph_*-crop.pdf' -exec pdftoppm -png {} {}.ppm \;
find . -name 'p_g_part_comp_*.tex' -exec pdflatex --output-format pdf {} \;
find . -name 'p_g_part_comp_*.pdf' -exec pdfcrop {} \;
find . -name 'p_g_part_comp_*-crop.pdf' -exec pdftoppm -png {} {}.ppm \;
