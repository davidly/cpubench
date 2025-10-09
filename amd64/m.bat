ml64 /nologo /Fl%1.lst /Zd /Zf /Zi %1.asm /link /OPT:REF /nologo /PDB:%1.pdb ^
  /subsystem:console /defaultlib:kernel32.lib ^
  /defaultlib:user32.lib ^
  /defaultlib:libucrt.lib ^
  /defaultlib:libcmt.lib ^
  /entry:mainCRTStartup


