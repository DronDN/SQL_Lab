#
#Database Name
#
$DatabaseName="PSDrive"
#
#Function for usage space
#
function FreeSpace($state) {
    Write-Host "Info $state inserting data" -ForegroundColor Green
    $QuerySpace="USE [$Databasename]; 
    GO
    Select DB_NAME() AS [DatabaseName], Name, file_id, physical_name,
    (size * 8.0/1024) as Size,
    ((size * 8.0/1024) - (FILEPROPERTY(name, 'SpaceUsed') * 8.0/1024)) As FreeSpace
    From sys.database_files;"
    Invoke-Sqlcmd -Query $QuerySpace | Format-Table -AutoSize         
}
#
#Log function
#
function Log($record) {
    $record=$record+(Get-Date) |Out-File C:\SQlScriptLogs.txt -Append
}
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
#
#Check and drop if exist
# 
$ServerInstance = New-Object Microsoft.SqlServer.Management.Smo.Server($env:COMPUTERNAME)
$SameDatabaseExist= 0
# 
$ServerInstance.Databases|ForEach-Object{if($_.name -eq $DatabaseName){$SameDatabaseExist = 1}}
# 
If ($SameDatabaseExist) 
    {
        Log("The database with the same name is exist")
        try 
            {
                Invoke-Sqlcmd -Query `
                "EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$DatabaseName'
                GO
                 USE [master]
                 GO
                DROP DATABASE [$DatabaseName]
                 GO" -ErrorAction Stop
                 Log("The database with the same name was droped")

            }
            catch 
            {
                Write-Host $error[0]
                Log("Cant drop the database with the same name ")
                Log($error[0])
            }
    }  
# 
#Create Database
#
#Query template
$CreateQuery1="CREATE DATABASE [$DatabaseName]
CONTAINMENT = NONE
ON  PRIMARY 
( NAME = N'$DatabaseName', FILENAME = N'E:\SQLDatabase\Data\$DatabaseName.mdf' , SIZE = 51200KB , FILEGROWTH = 5120KB )
LOG ON 
( NAME = N'$DatabaseName+_log', FILENAME = N'E:\SQLDatabase\Logs\$DatabaseName+_log.ldf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
GO
ALTER DATABASE [$DatabaseName] SET COMPATIBILITY_LEVEL = 110
USE [$DatabaseName]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [$DatabaseName] MODIFY FILEGROUP [PRIMARY] DEFAULT;"

#Creation invoke
try {
    Invoke-Sqlcmd -Query $CreateQuery1 -ErrorAction Continue
    Log("The database $DatabaseName was created")
}
catch {
    Write-Host "Can't create database $DatabaseName" -ForegroundColor Red
    Write-Host $error[0]
    Log("Can't create database $DatabaseName")
    Log($error[0])
}
#
#Create new table
#
$TableName="Disks"
#Query template
$QueryTable="USE $DatabaseName
GO
IF OBJECT_ID('dbo.$TableName', 'U') IS NOT NULL
  DROP TABLE dbo.$TableName
GO
CREATE TABLE dbo.$TableName
(
	FriendlyName varchar(50) NOT NULL,
	BusType varchar(50) NOT NULL, 
	HealthStatus varchar(50) NOT NULL, 
    MediaType varchar(50) NOT NULL,
    Size varchar(50) NOT NULL,
	CONSTRAINT PK_Disk PRIMARY KEY (FriendlyName)
);"

try {
    Invoke-Sqlcmd -Query $QueryTable -ErrorAction Stop
    Log("The database $TableName was created") 
}
catch {
    Write-Host "Can't create database $TableName" -ForegroundColor Red
    Write-Host $error[0]
    Log("Can't create table $TableName")
    Log($error[0])
}
#
FreeSpace("before")
#
#Insert data
#
$Drives =(Get-PhysicalDisk | Select-Object -Property FriendlyName,BusType,HealthStatus,Size,MediaType)

try {
   foreach($Drive in $drives) {`
    $QueryInsert="USE $DataBaseName

    INSERT INTO dbo.$TableName
           ([FriendlyName]
           ,[BusType]
           ,[HealthStatus]
           ,[MediaType]
           ,[Size])
     VALUES
           (`'$($Drive.FriendlyName)`',
            `'$($Drive.BusType)`',
            `'$($Drive.HealthStatus)`',
            `'$($Drive.MediaType)`',
            `'$($Drive.Size)`');"

    Invoke-Sqlcmd -Query $QueryInsert -ErrorAction Stop}
    Log("Insert data in table $TableName")
}
catch {
    Write-Host "Can't insert in  $TableName" -ForegroundColor Red
    Write-Host $error[0]
    Log("Can't insert data in table $TableName")
    Log($error[0])
}
#
FreeSpace('after')

Write-Host "You can find Logs C:\SQlScriptLogs.txt" -ForegroundColor DarkGreen

