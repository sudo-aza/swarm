# ctable
     key | description
     ---:|:---
  ctable | package for flexible key/value driven typesetting of floats
 version | 1.33
    date | 2025/10/22
  author | Wybo Dekker
   email | wybodekker@me.com
 license | Released under the LaTeX Project Public License v1.3c or later

## Short description:
ctable.sty provides commands to easily typeset centered or left or right
aligned table and (multiple-)figure floats, with footnotes. Instead of an
environment, a command with 4 arguments is used; the first is optional and
is used for key,value pairs generating variations on the defaults and
offering a route for future extensions.

# Installation:
This is a self-extracting file. Install as follows:
1. Run "tex ctable.dtx"
2. Run "sh make.sh"
3. Run "make install" to install in the local tree (needs sudo rights), or
   Run "make inst" to install in your own tree.
4. Run "make clean" to remove most intermediate files, or
   Run "make Clean" to keep the dtx file and CTAN zip only.
5. Run "make zip" to create a zip file for CTAN
6. Try "make help"
