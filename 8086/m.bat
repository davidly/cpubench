del %1.map 2>nul
del %1.exe 2>nul
del %1.lst 2>nul
del %1.obj 2>nul

ntvdm -h bin\masm /Zi /Zd /z /l %1,,,;
ntvdm -h bin\link /CP:1 %1,,%1,,nul.def

