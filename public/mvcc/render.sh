#!/bin/sh
#thanks to https://tex.stackexchange.com/questions/11866/compile-a-latex-document-into-a-png-image-thats-as-short-as-possible
find . -name '*.tex' -exec pdflatex --output-format pdf {} \;
find . -name '*.pdf' -exec pdfcrop {} \;
find . -name '*-crop.pdf' -exec pdftoppm -png {} {}.ppm \;
for pic in $(find . -name '*-crop*.png'); do
  prefix=$(echo $pic | sed 's/-crop.*//')
  mv "$pic" "${prefix}.png"
done
find . -name '*-crop*.pdf' -exec rm {} \;
find . -name '*.aux' -exec rm {} \;
find . -name '*.log' -exec rm {} \;
find . -name '*.pdf' -exec rm {} \;
