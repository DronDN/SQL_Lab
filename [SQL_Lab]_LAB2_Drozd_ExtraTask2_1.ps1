# Base names
$DatabaseName1="HumanResources"
$DatabaseName2="InternetSales"
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
#
# Check for same database name
#
$ServerInstance = New-Object Microsoft.SqlServer.Management.Smo.Server($env:COMPUTERNAME)
    #flags   
$SameDatabaseExist1= 0
$SameDatabaseExist2 = 0
$ServerInstance.Databases|ForEach-Object{if($_.name -eq $DatabaseName1){ $SameDatabaseExist1 = 1}}
$ServerInstance.Databases|ForEach-Object{if($_.name -eq $DatabaseName2){ $SameDatabaseExist2 = 2}}
#
#Drops database if it exist
#
If ($SameDatabaseExist1) 
    {
        try 
            {
                Invoke-Sqlcmd -Query `
                "EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$DatabaseName1'
                GO
                 USE [master]
                 GO
                DROP DATABASE [$DatabaseNAme1]
                 GO" -ErrorAction Stop
            }
            catch 
            {
                Write-Host $error[0]
            }
    }  
# 
If ($SameDatabaseExist2) 
    {
        try 
            {
                Invoke-Sqlcmd -Query `
                "EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$DatabaseName2'
                GO
                USE [master]
                GO
                DROP DATABASE [$DatabaseName2]
                GO" -ErrorAction Stop
            }
        catch 
            {
                Write-Host $error[0]
            }   
    }    
#
#Create first Database
#
#Query template
$CreateQuery1="CREATE DATABASE [$DatabaseName1]
CONTAINMENT = NONE
ON  PRIMARY 
( NAME = N'$DatabaseName1', FILENAME = N'E:\SQLDatabase\Data\$DatabaseName1.mdf' , SIZE = 51200KB , FILEGROWTH = 5120KB )
LOG ON 
( NAME = N'$DatabaseName1+_log', FILENAME = N'E:\SQLDatabase\Logs\$DatabaseName1+_log.ldf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
GO
ALTER DATABASE [$DatabaseName1] SET COMPATIBILITY_LEVEL = 110
USE [$DatabaseName1]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [$DatabaseName1] MODIFY FILEGROUP [PRIMARY] DEFAULT;"
try {
    Invoke-Sqlcmd -Query $CreateQuery1 -ErrorAction Continue
}
catch {
    Write-Host "Can't create database $DatabaseName1" -ForegroundColor Red
    Write-Host $error[0]
}
#
#Create second Database
#
#Query template
$CreateQuery2 = "CREATE DATABASE [$DatabaseName2]
CONTAINMENT = NONE
ON  PRIMARY 
( NAME = N'$DatabaseName2', FILENAME = N'E:\SQLDatabase\Data\$DatabaseName2.mdf' , SIZE =5120KB , FILEGROWTH = 1024KB ), 
FILEGROUP [SalesData] 
( NAME = N'$DatabaseName2+_data1', FILENAME = N'E:\SQLDatabase\AdditionalData\$DatabaseName2+_data1.ndf' , SIZE = 102400KB , FILEGROWTH = 10240KB ), 
( NAME = N'$DatabaseName2+_data2', FILENAME = N'E:\SQLDatabase\Data\$DatabaseName2+_data2.ndf' , SIZE = 102400KB , FILEGROWTH = 10240KB )
LOG ON 
( NAME = N'$DatabaseName2+_log', FILENAME = N'E:\SQLDatabase\Logs\$DatabaseName2+_log.ldf' , SIZE = 2048KB , FILEGROWTH = 10%)
GO
USE [$DatabaseName2]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'SalesData') ALTER DATABASE [$DatabaseName2] MODIFY FILEGROUP [SalesData] DEFAULT;"

try {
    Invoke-Sqlcmd -Query $CreateQuery2 -ErrorAction Continue
}
catch {
    Write-Host "Can't create database $DatabaseName2" -ForegroundColor Red
    Write-Host $error[0]
}

