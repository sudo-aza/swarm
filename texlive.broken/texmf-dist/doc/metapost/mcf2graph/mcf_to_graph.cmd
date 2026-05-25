:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::  Batch file for compile MCF  2025.09.15
::  <drag and drop library or metapost file on this batch>
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
@echo off
if %~x1 == .mp (
if %~n1 == mcf2graph goto end
mkdir %~n1-mp
mpost -output-directory=./%~n1-mp %~n1
goto end )
if not %~x1 == .mcf goto end
echo **** Select output format / Library file [%~n1] ****
echo [1:svg 2:png-600dpi 3:png-1200dpi 4:MOL-v2000 5:MOL-v3000 6:report 0:cancel]
choice /c 1234560
if %errorlevel% == 7 goto end
echo input mcf2graph; libm:="%~n1.mcf"; loadm() allm bye> temp_soc.mp
if %errorlevel% == 1 (mkdir %~n1-svg
mpost -output-directory=./%~n1-svg temp_soc)
if %errorlevel% == 2 (mkdir %~n1-pn0600
mpost -output-directory=./%~n1-pn0600 -s ahangle=1 temp_soc)
if %errorlevel% == 3 (mkdir %~n1-pn1200
mpost -output-directory=./%~n1-pn1200 -s ahangle=2 temp_soc)
if %errorlevel% == 4 (mkdir %~n1-molv2k
mpost -output-directory=./%~n1-molv2k -s ahlength=5 temp_soc)
if %errorlevel% == 5 (mkdir %~n1-molv3k
mpost -output-directory=./%~n1-molv3k -s ahlength=6 temp_soc)
if %errorlevel% == 6 (mkdir %~n1-report
mpost -output-directory=./%~n1-report -numbersystem=double -s ahlength=7 temp_soc)
del temp_soc.mp
:end