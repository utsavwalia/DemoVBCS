@echo off
cd C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin
set PATH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin;%PATH%
call C:\WINDOWS\system32\regsvr32.exe /s %1
exit /B %ERRORLEVEL%
