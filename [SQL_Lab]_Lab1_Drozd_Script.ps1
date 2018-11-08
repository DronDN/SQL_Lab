# Скрипт предполагает, что выполняются условия текущей лабораторной работы
#(этот комрьютер находится в одной сети с неким сервером, где расшаренна папка с дистрибьютивом windows,
# файлом .ini; также на компьютере в дисководе есть диск с SQL;
#Предполагается, что путь к данным ресурсам можно поменять;
#Также командная строка будет запущена от имени Администратора
[CmdletBinding()]
Param(
#Имя папки для бэкапа
    [parameter(Mandatory=$false,HelpMessage="Enter fullname for backup directory")]
    [string]$BackUpDir="ForSQLBackUp",
#Путь к ConfigurationFile.ini
    [parameter(Mandatory=$false,HelpMessage="Path for .ini file")]
    [string]$FirstIniFilePath="\\169.254.227.128\ForSQL\ConfigurationFile.ini",
#Путь к .net
    [parameter(Mandatory=$false,HelpMessage="Path for .net ")]
    [string]$NetFilePath="\\169.254.227.128\d\Sources\sxs",

    )

#Пароль для sa
$SAPassword= Read-Host "Enter Sa account password" -AsSecureString

#Определение driveletter системного диска
$SysDriveLetter=($env:SystemDrive).Replace(":","")

#Определение driveletter системного диска
$CDROMLetter=(Get-WmiObject -Class win32_LogicalDisk|Where-Object{$_.description -match "CD-Rom"}).DeviceID.Replace(":","")

#Проверка свободного места на системном диске для установки
$freespace=(Get-WmiObject -Class win32_LogicalDisk|Where-Object{$_.DeviceId -match "$SysDriveLetter"}).Freespace
if ($freespace -le 4GB) {
    Write-host "Not enough memory";
    break
    }

#Проверка на количество дисков. В случае наличия только системного создается новый том объемом 1GB для бэкапа, иначе бекап на любом не 
# системном и не CDROM или по указанному адресу
$diskcount=(Get-Partition).Count
If ($diskcount -le 2) {
$size = (Get-PartitionSupportedSize -DriveLetter $SysDriveLetter).SizeMax
Resize-Partition -DriveLetter $SysDriveLetter -Size ($size - 1GB)
#Определяем букву нового тома
    if($SysDriveLetter -ne "B"){ 
       $NewDiskLetter="B"
       }
    else{
        [int32]$NewDiskLetter=[char]($SysDriveLetter)
        [char]$NewDiskLetter=($NewDiskLetter + 1)
        }
#Создаем новый том и папку для  backup
New-Partition -DiskNumber 0 -DriveLetter $NewDiskLetter -Size 1GB
Format-Volume -Driveletter $NewDiskLetter -FileSystem NTFS
$BackUpDirectory=(New-Item -Path $($NewDiskLetter+":\") -Name $BackUpDir -ItemType Directory).FullName

}elif ($BackUpDir -eq "ForSQLBackUp"){
 $NewDiskLetter=(Get-WmiObject -Class win32_LogicalDisk|Where-Object{$_.freespace -gt 1GB}|sort -Descending|select -First 1).DeviceID +"\"   
 $BackUpDirectory = (New-Item -Path $NewDiskLetter -Name $BackUpDir -ItemType Directory).FullName
#Предполагатся, что будет введен полный адрес
}else {
 $BackUpDirectory = $BackUpDir
} 
#Проверяем установлен ли .Net Framework 3.5

$NetFr=(Get-WindowsFeature *framework*|Where-Object{($_.displayname -match "3.5") -and ($_.installstate -eq "installed")})
#Если нет, то ставим
if (!$NetFr){
    Dism.exe /online /enable-feature /featurename:NetFX3 /All /Source:$NetFilePath /LimitAccess
    }

#Конфигурируем файл COnfigurationFile.ini под текущую машину
#файл предварительно подготовлен(имя instance заменено на qwerty и т.д..Файл прилагается)
$CompSQL=$env:COMPUTERNAME+'SQL'
$IntDir="$SysDriveLetter`:\Program Files\Microsoft SQL Server"
$ShareWOWDir="$SysDriveLetter`:\Program Files (x86)\Microsoft SQL Server"
(Get-Content -Path $FirstIniFilePath) | ForEach-Object {$_ `
   -replace "QWERTY","$CompSQL"`
   -replace "Comp","$env:COMPUTERNAME"`
   -replace "BackUpDirectory","$BackUpDirectory"`
   -replace "DDSHAREDDIRDD","$IntDir"`
   -replace "DDINSTANCEDIRDD","$IntDir"`
   -replace "DDSHAREDWOWDIRDD","$ShareWOWDir"`
} | Set-Content -Path "$SysDriveLetter`:\ConfigurationFile.ini"
 
 #Ставим SQLServer
 $SQLSetup ="$SysDriveLetter`:\Setup.exe"
 $ConfigFile ="$SysDriveLetter`:\ConfigurationFile.ini"
 & $SQLSetup /ConfigurationFile=$COnfigFile /IACCEPTSQLSERVERLICENSETERMS /SAPWD= $SAPassword 

 #Отрываем порты TCP 1433 , UDP 1434, TCP 80 и открываем доступ к SQL Server при использовании динамических портов

 netsh advfirewall firewall add rule name = SQLPort dir = in protocol = tcp action = allow localport = 1433 remoteip = localsubnet profile = any
 netsh advfirewall firewall add rule name = ReportService dir = in protocol = tcp action = allow localport = 80 remoteip = localsubnet profile =any
 netsh advfirewall firewall add rule name = SQLUDP dir = in protocol = udp action = allow localport = 1434 remoteip = localsubnet profile =any
 netsh advfirewall firewall add rule name="Allow SQL Server" dir=in action=allow program="$SysDriveLetter`:\Program Files\Microsoft SQL Server\MSSQL11.$CompSQL\MSSQL\Binn\Sqlservr.exe"
 #Включаем RDP
 netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
 (Get-WMIObject -class Win32_TerminalServiceSetting -Namespace ROOT\CIMV2\TerminalServices).SetAllowTSConnections(1)
 (Get-WmiObject -class Win32_TSGeneralSetting -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0)
 #Выключаем динамические порты TCP/Ip и включаем их на 1433
 $Wmi = (New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') $env:COMPUTERNAME)
 $uri = ("ManagedComputer[@Name='$env:COMPUTERNAME']/ ServerInstance[@Name='$CompSQL']/ServerProtocol[@Name='Tcp']") 
 $Tcp = ($wmi.GetSmoObject($uri))
 $wmi.GetSmoObject($uri + "/IPAddress[@Name='IPAll']").IPAddressProperties[0].Value=""
 $wmi.GetSmoObject($uri + "/IPAddress[@Name='IPAll']").IPAddressProperties[1].Value="1433"
 $tcp.Alter()
 #Грузим сервис 
 $serviceName=(Get-Service *MSSQ*).Name
 Restart-Service -Name $serviceName
 #returns name of installed SQL instance, and VM name in human readable view
 $Wmi = (New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') $env:COMPUTERNAME)
 Write-Host "ServerInstanses:"
 $wmi.ServerInstances|FT -Property Name
 #returns list of installed SQL features in any human readable format
 Get-Content "$SysDriveLetter`:\Program Files\Microsoft SQL Server\110\Setup Bootstrap\Log\Summary.txt"
 #returns Firewall state and settings, that were changed by Student

