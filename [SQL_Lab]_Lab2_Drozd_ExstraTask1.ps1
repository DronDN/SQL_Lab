# Скрипт написан для удаленной машины (то того, как дали пояснения в Skype)
# переделывать не стал
# Подразумевается, что на $Comp есть диск E:
# Решение использовать CIM было неудачным, т.к. скрипт получился ну очень медленным
Param(
[parameter(Mandatory=$false,HelpMessage="Enter computer name or ip")]
[String]$Comp="169.254.227.128",
#New Path for tempdb.mdf
[parameter(Mandatory=$false,HelpMessage="Enter new path for tempdb.mdf")]
[String]$DevTempPath="E:\TempSQL\",
#size for tempdb.mdf
[parameter(Mandatory=$false,HelpMessage="Enter size for tempdb.mdf")]
[String]$DevTempSize="10",
#maxsize for tempdb.mdf
[parameter(Mandatory=$false,HelpMessage="Enter maxsize for tempdb.mdf('Unlimited' or size in MB)")]
[string]$DevTempMaxSize="Unlimited",
#growth for tempdb.mdf
[parameter(Mandatory=$false,HelpMessage="Enter growth for tempdb.mdf")]
[string]$DevTempGrowth="5",
#The same things for templog.ldf
[parameter(Mandatory=$false,HelpMessage="Enter new path for templog.ldf")]
[String]$LogTempPath="E:\TempSQL\",
[parameter(Mandatory=$false,HelpMessage="Enter size for templog.ldf")]
[int]$LogTempSize="10",
[parameter(Mandatory=$false,HelpMessage="Enter maxsize for templog.ldf('Unlimited' or size in MB)")]
[string]$LOGTempMaxSize="Unlimited",
[parameter(Mandatory=$false,HelpMessage="Enter growth for templog.ldf")]
[string]$LogTempGrowth="1"
)
#
$sa=Get-Credential -Credential sa
$admin=Get-Credential -Credential Administrator
$ErrorActionPreference = "Stop"
#Full path
$DevTempPathFull = $DevTempPath+"tempdb.mdf"
$LogTempPathFull = $LogTempPath+"templog.ldf"

#Current values
Write-Host "Current values" -ForegroundColor DarkBlue 

try {
        $CurrentValues=Invoke-Sqlcmd -ServerInstance $Comp -Credential $sa -Query "SELECT name, physical_name,size,max_size,growth 
        FROM sys.master_files WHERE database_id = DB_ID(N'tempdb');" 
    }
catch 
    {
        Write-Host $Error[0]
    }
$CurrentValues|Format-Table Name,Physical_name,`
@{n="Size (MB)";e={$_.size/128};},`
@{n="max_size"; e={if($_.max_size -eq -1){"Unlimited"}else{$_.max_size}}},`
@{n="growth (MB)";e={$_.growth/128}}

#checking the existing files with the same name in the target location
try {
    $ExFiles=Get-WmiObject -Class CIM_DataFile -Filter "Drive='E:' AND (FileName='Tempdb' OR FileName='Templog') AND (Extension='mdf' OR Extension='ldf')"`
-ComputerName $Comp -Credential $admin
}
catch {
    Write-Host $Error[0]
}

If ($ExFiles)
    {
        Write-Host "Files already exist" -ForegroundColor DarkRed
        Break
    }

#Current free space on disks
$fsBefore=0
Get-WmiObject -class CIM_LogicalDisk -ComputerName $Comp -Credential $admin |ForEach-Object{$fsBefore +=$_.freespace}
Write-Host "Total current free space :" -NoNewline
Write-Host "$($fsBefore/1mb)" -ForegroundColor Green

#Change value
#Invoke-Sqlcmd -ServerInstance $Comp -Credential $sa -Query " Use master;"
try {
    Invoke-Sqlcmd -ServerInstance $Comp -Credential $sa `
     -Query "ALTER DATABASE tempdb Modify file (Name = tempdev, size =$DevTempSize, filegrowth = $DevTempGrowth,
    maxsize=$DevTempMaxSize, FILENAME =`"$devtemppathfull`");"
    Invoke-Sqlcmd -ServerInstance $Comp -Credential $sa `
     -Query "ALTER DATABASE tempdb Modify file (Name =templog, size = $LogTempSize, filegrowth = $LogTempGrowth,
      maxsize=$LOGTempMaxSize, FILENAME = `"$LogTempPathFull`");"
}
catch {
    Write-Host $Error[0]
}

#Stop MSSQL
try {
    $SQLAgent = Get-WmiObject -Class CIM_Service -Filter 'Name="SQLSERVERAGENT"' -ComputerName $Comp -Credential $admin
    if ($SQLAgent.state -eq "Running")
        {
            $SQLAgentStop=Get-WmiObject -Class CIM_Service -Filter 'Name="SQLSERVERAGENT"' -ComputerName $comp -Credential $admin | Invoke-WmiMethod -Name StopService
            if ($SQLAgentStop.ReturnValue -eq 0)
                {
                    Write-Host "SqlAgentService successfully stoped" -ForegroundColor DarkRed
                }
            else
                {
                    Write-Host "Can't stop SQLAgentService" -ForegroundColor DarkRed
                }    
            $SQLserverStop=Get-WmiObject -Class CIM_Service -Filter 'Name="MSSQLSERVER"' -ComputerName $comp -Credential $admin | Invoke-WmiMethod -Name StopService
            if ($SQLserverStop.ReturnValue -eq 0)
                {
                    Write-Host "MSSqlService successfully stoped" -ForegroundColor DarkRed
                }
            else
                {
                    Write-Host "Can't stop MSSQLService" -ForegroundColor DarkRed
                }    
        }
    else 
        {
            $SQLserverStop=Get-WmiObject -Class CIM_Service -Filter 'Name="MSSQLSERVER"' -ComputerName $comp -Credential $admin | Invoke-WmiMethod -Name StopService
            if ($SQLserverStop.ReturnValue -eq 0)
                {
                    Write-Host "MSSqlService successfully stoped" -ForegroundColor DarkRed
                }
            else
                {
                    Write-Host "Can't stop MSSQLService" -ForegroundColor DarkRed
                }    
        }

}
catch {
    write-host $Error[0]
}

#Delete old files
try {
    $Deleting= (Get-WmiObject -Class CIM_DataFile -Filter "Drive='C:' AND (FileName='Tempdb' OR FileName='Templog') AND (Extension='mdf' OR Extension='ldf')"`
    -ComputerName $comp -Credential $admin |Invoke-WmiMethod -Name Delete -ErrorAction Continue)
}
catch {
    Write-Host $Error[0]
}
if($Deleting.ReturnValue -eq 0)
    {
        Write-Host "The files are deleted" -ForegroundColor DarkGreen
    } 
#Start MSQServer
try {
    $MSQLStart = Get-WmiObject -Class CIM_Service -Filter 'Name="MSSQLSERVER"' -ComputerName $comp -Credential $admin | Invoke-WmiMethod -Name StartService -ErrorAction Stop
}
catch {
    Write-Host $error[0]
}
if ($MSQLStart.ReturnValue -eq 0)
    {
        Write-Host "MSSqlService successfully started" -ForegroundColor DarkGreen
    }
#values after change
Write-Host "Values after change" -ForegroundColor DarkBlue 
Invoke-Sqlcmd -ServerInstance $Comp -Credential $sa `
 -Query "SELECT name, physical_name,size,max_size,growth FROM sys.master_files WHERE database_id = DB_ID(N'tempdb');"`
 |Format-Table Name,Physical_name,@{n="Size (MB)";e={$_.size/128};},`
@{n="max_size"; e={if($_.max_size -eq -1){"Unlimited"}else{$_.max_size}}},`
@{n="growth (MB)";e={$_.growth/128}}

#free space on disks after change
$fsafter=0
Get-WmiObject -class CIM_LogicalDisk -ComputerName $Comp -Credential $admin |ForEach-Object{$fsafter +=$_.freespace}
Write-Host "Total free space after change :" -NoNewline
Write-Host "$($fsafter/1mb)" -ForegroundColor Green
Write-Host "Difference :" -NoNewline
Write-Host $(($fsBefore - $fsafter)/1MB) -ForegroundColor DarkBlue

