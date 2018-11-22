$Password ="qwerty"
$CertPassword = "Certqwerty"
$DataBaseName = "User_db"
$CSVPath = 'C:\Users\DDN\Documents\Lab4.csv'
$CompName = $env:COMPUTERNAME

#############################################
#Function for create users at local computer
#############################################
function CreateWinUser ($Username, $user_password)
{
    net user $Username $user_password /add     
}
###############################
#Get list of windows users
###############################
$CurrentUsers = Get-WmiObject win32_userAccount

###############################
#Get content csv file
###############################
$Users = Import-Csv -Path $CSVPath

###################################################
#Create new windows local user if it does not exist
###################################################
foreach($user in $Users)`
{
    if($CurrentUsers.Name -contains $User.Name)
        {
            Write-Host "User $($User.Name) exist"
        }
    Else 
        {
            CreateWinUser($User.Name,$user.PASSWORD)
        }
}

###################################################
#Create SQL Logins with windows authentication
#For each function we have dafault permissions
###################################################


foreach($user in $Users)`
{
  switch ($User.Function) 
    {
    "Dev" 
        {
        $QueryDev = "USE [master]
        GO
        CREATE LOGIN [$CompName\$($user.Name)] FROM WINDOWS WITH DEFAULT_DATABASE=[$DatabaseName]
        GO
        CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
        GO
        USE [$DatabaseName]
        ALTER ROLE [db_datareader] ADD MEMBER [$CompName\$($user.Name)]
        ALTER ROLE [db_datawriter] ADD MEMBER [$CompName\$($user.Name)]
        USE [$DatabaseName]
        ALTER ROLE [db_owner] DROP MEMBER [];" 
        Invoke-Sqlcmd -Query $QueryDev 
        }
    "test"
        { 
            $QueryQA = "USE [master]
            CREATE LOGIN [$CompName\$($user.Name)] FROM WINDOWS WITH DEFAULT_DATABASE=[$Databasename]
             GO
            USE [$Databasename]
            CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
            ALTER ROLE [db_datareader] ADD MEMBER [$CompName\$($user.Name)]
            ALTER ROLE [db_datawriter] ADD MEMBER [$CompName\$($user.Name)]
            ALTER ROLE [db_owner] DROP MEMBER [];"
            Invoke-Sqlcmd -Query $QueryQA 
        }
    "service app"
        { 
            $QueryAPP =  "USE [master]
            GO
            CREATE LOGIN [$CompName\$($user.Name)] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
            Use [$databaseName]
            CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
            ALTER ROLE [db_backupoperator] ADD MEMBER [$CompName\$($user.Name)]
            ALTER ROLE [db_ddladmin] ADD MEMBER [$CompName\$($user.Name)]
            ALTER ROLE [db_owner] DROP MEMBER []
            GRANT ALTER ON $TableName TO [$CompName\$($user.Name)]
            GRANT CONTROL ON $TableName TO [$CompName\$($user.Name)]
            GRANT DELETE ON $TableName TO [$CompName\$($user.Name)];"
            Invoke-Sqlcmd -Query $QueryAPP 
        }
    "service user" 
        { 
            $QueryService = "USE [master]
            GO
            CREATE LOGIN [$CompName\$($user.Name)] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
            Use [$databaseName]
            CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
            ALTER ROLE [db_backupoperator] ADD MEMBER [$CompName\$($user.Name)]
            ALTER ROLE [db_ddladmin] ADD MEMBER [$CompName\$($user.Name)]
            ALTER ROLE [db_owner] DROP MEMBER []
            DENY DELETE TO [$CompName\$($user.Name)];"
            Invoke-Sqlcmd -Query $QueryService 
        }
    "backup user" 
    { 
        $QueryBackUper = "USE [master]
        GO
        CREATE LOGIN [$CompName\$($user.Name)] FROM WINDOWS WITH DEFAULT_DATABASE=[User_db]
        USE [master]
        CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
        ALTER ROLE [db_backupoperator] ADD MEMBER [$CompName\$($user.Name)]
        GO
        USE [model]
        CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
        ALTER ROLE [db_backupoperator] ADD MEMBER [$CompName\$($user.Name)]
        GO
        USE [msdb]
        CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
        ALTER ROLE [db_backupoperator] ADD MEMBER [$CompName\$($user.Name)]
        GO
        USE [$DatabaseName]
        CREATE USER [$CompName\$($user.Name)] FOR LOGIN [$CompName\$($user.Name)]
        ALTER ROLE [db_backupoperator] ADD MEMBER [$CompName\$($user.Name)]
        ALTER ROLE [db_denydatareader] ADD MEMBER [$CompName\$($user.Name)]
        ALTER ROLE [db_owner] DROP MEMBER [];" 
        Invoke-Sqlcmd -Query $QueryBackUper 
    }
    Default { Write-Host "User function $($User.Function) does not exist"}
  }
}

###############################
#Encrypt select database
###############################
$EncryptQuery = " Use master;
CREATE MAster KEY ENCRYPTION BY PASSWORD = '$Password';

CREATE CERTIFICATE $CerfName WITH SUBJECT = 'DEK_Certificate';

BACKUP CERTIFICATE Security_Certificate TO FILE = 'E:\SQLBackUp\security_certificate.cer'
WITH PRIVATE KEY 
(FILE = 'E:\SQLBackUp\security_certificate.key' ,
ENCRYPTION BY PASSWORD = '$CertPassword');

USE [$DataBaseName];
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE Security_Certificate;

ALTER DATABASE [$DataBaseName]
SET ENCRYPTION ON;"
try 
{
    Invoke-Sqlcmd -Query $EncryptQuery -ErrorAction stop
}

catch 
{
    Write-Host $Error[0].Extension  
}