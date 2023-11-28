﻿<# ----- About: ----
    # N-able | Cove Data Protection | M365 User Cleanup 
    # Revision 23.11 - 2023-11-28
    # Author: Eric Harless, Head Backup Nerd - N-able 
    # Twitter @Backup_Nerd  Email:eric.harless@n-able.com
    # Reddit https://www.reddit.com/r/Nable/
# -----------------------------------------------------------#>  ## About

<# ----- Legal: ----
    # Sample scripts are not supported under any N-able support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # N-able expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose. 
    # In no event shall N-able or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------#>  ## Legal

<# ----- Compatibility: ----
    # For use with the Standalone edition of N-able Backup
    # Sample scripts may contain non-public API calls which are subject to change without notification
  
# -----------------------------------------------------------#>  ## Compatibility

<# ----- Behavior: ----
    # Check/ Get/ Store secure credentials 
    # Authenticate to https://backup.management console
    # Check partner level/ Enumerate partners/ GUI select partner
    # Enumerate devices/ GUI select M365 devices
    # Optionally export to XLS/CSV
    # Optionally import CSV to adjust Mail and OneDrive selections
    #
    # Use the -AllPartners switch parameter to skip GUI partner selection
    # Use the -AllDevices switch parameter to skip GUI device selection
    # Use the -DeviceCount ## (default=5000) parameter to define the maximum number of devices returned
    #
    # Use the -ExportCombined switch parameter to export combined M365 device and user statistics to XLS/CSV files
    # Use the -ExportPath (?:\Folder) parameter to specify XLS/CSV file path
    # Use the -Launch switch parameter to launch the XLS/CSV file after completion
    # Use the -ClearCredentials parameter to remove stored API credentials at start of script
    #
    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/json-api/home.htm
    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/json-api/API-column-codes.htm

# -----------------------------------------------------------#>  ## Behavior

[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$False)] [switch]$AllPartners,                       ## $AllPartners = $true, to Skip GUI partner selection
        [Parameter(Mandatory=$False)] [switch]$AllDevices,                        ## $AllDevices = $true, to Skip GUI device selection
        [Parameter(Mandatory=$False)] [int]$DeviceCount = 10000,                  ## Set maximum number of device / domain results to return

        [Parameter(Mandatory=$False)] [switch]$ExportCombined = $true,            ## Generate combined XLS/CSV output files for M365 devices and users
        [Parameter(Mandatory=$False)] [switch]$Launch,                            ## Launch combined XLS/CSV outputfile if generated

        [Parameter(Mandatory=$False)] [switch]$ExportSharedBillable = $true,      ## Export Billable Shared Mailboxes with Onedrive History
        [Parameter(Mandatory=$False)] [switch]$CleanupSharedBillable = $true,             ## Prompt to Cleanup Billable Shared Mailboxes with Onedrive History
        [Parameter(Mandatory=$False)] [int]$OneDriveAge = 45,                     ## Ignore Billable Shared Mailboxes with OneDrive Backups in the last X Days 

        [Parameter(Mandatory=$False)] [switch]$ExportDeleted = $true,             ## Export Deleted Mailboxes
        [Parameter(Mandatory=$False)] [switch]$CleanupDeleted = $true,                    ## Prompt to Cleanup Deleted Mailboxes
        [Parameter(Mandatory=$False)] [int]$DeletedAge = 45,                      ## Ignore Deleted Mailboxes in the last X Days

        [Parameter(Mandatory=$False)] [string]$ExportPath = "$PSScriptRoot",                                ## Export Path
        [Parameter(Mandatory=$False)] [string]$delimiter = ",",                                             ## Delimiter
        [Parameter(Mandatory=$False)] [switch]$ClearCredentials                                             ## Remove Stored API Credentials at start of script
    )

#region ----- Environment, Variables, Names and Paths ----
    Clear-Host
    #Requires -Version 5.1
    $ConsoleTitle = "M365 User Cleanup"
    $host.UI.RawUI.WindowTitle = $ConsoleTitle
    $scriptpath = $MyInvocation.MyCommand.Path
    Write-output "  $ConsoleTitle`n`n$ScriptPath"
    $Syntax = Get-Command $PSCommandPath -Syntax 
    Write-Output "  Script Parameter Syntax:`n`n  $Syntax"

    $dir = Split-Path $scriptpath
    Push-Location $dir
    $CurrentDate = Get-Date -format "yyyy-MM-dd_HH-mm-ss"
    $ShortDate = Get-Date -format "yyyy-MM-dd"
    if ($ExportPath) {$ExportPath = Join-path -path $ExportPath -childpath "M365_$shortdate"}else{$ExportPath = Join-path -path $dir -childpath "M365_$shortdate"}
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Script:strLineSeparator = "  ---------"
    If ($exportcombined) {mkdir -force -path $ExportPath | Out-Null}
    $urlJSON = 'https://api.backup.management/jsonapi'

    $culture = get-culture; $delimiter = $culture.TextInfo.ListSeparator

    Write-output "  Current Parameters:"
    Write-output "  -AllPartners     = $AllPartners"
    Write-output "  -AllDevices      = $AllDevices"
    Write-output "  -DeviceCount     = $DeviceCount"
    Write-output "  -GridView        = $GridView"
    Write-output "  -ExportCombined  = $ExportCombined"
    Write-output "  -ExportShared    = $ExportSharedBillable"
    Write-output "  -CleanupShared   = $CleanupSharedBillable"
    Write-output "  -ExportDeleted   = $ExportDeleted"
    Write-output "  -CleanupDeleted  = $CleanupDeleted"
    Write-output "  -ExportPath      = $ExportPath"
    Write-output "  -Delimiter       = $delimiter"
    
#endregion ----- Environment, Variables, Names and Paths ----

#region ----- Functions ----

#region ----- Authentication ----
Function Set-APICredentials {

    Write-Output $Script:strLineSeparator 
    Write-Output "  Setting Backup API Credentials" 
    if (Test-Path $APIcredpath) {
        Write-Output $Script:strLineSeparator 
        Write-Output "  Backup API Credential Path Present" }else{ New-Item -ItemType Directory -Path $APIcredpath} 

        Write-Output "  Enter Exact, Case Sensitive Partner Name for N-able Backup.Management API i.e. 'Acme, Inc (bob@acme.net)'"
    DO{ $Script:PartnerName = Read-Host "  Enter Login Partner Name" }
    WHILE ($PartnerName.length -eq 0)
    $PartnerName | out-file $APIcredfile

    $BackupCred = Get-Credential -UserName "" -Message 'Enter Login Email and Password for N-able Backup.Management API'
    $BackupCred | Add-Member -MemberType NoteProperty -Name PartnerName -Value "$PartnerName" 

    $BackupCred.UserName | Out-file -append $APIcredfile
    $BackupCred.Password | ConvertFrom-SecureString | Out-file -append $APIcredfile
    
    Start-Sleep -milliseconds 300

    Send-APICredentialsCookie  ## Attempt API Authentication

}  ## Set API credentials if not present

Function Get-APICredentials {

    $Script:True_path = "C:\ProgramData\MXB\"
    $Script:APIcredfile = join-path -Path $True_Path -ChildPath "$env:computername API_Credentials.Secure.txt"
    $Script:APIcredpath = Split-path -path $APIcredfile

    if (($ClearCredentials) -and (Test-Path $APIcredfile)) { 
        Remove-Item -Path $Script:APIcredfile
        $ClearCredentials = $Null
        Write-Output $Script:strLineSeparator 
        Write-Output "  Backup API Credential File Cleared"
        Send-APICredentialsCookie  ## Retry Authentication
        
        }else{ 
            Write-Output $Script:strLineSeparator 
            Write-Output "  Getting Backup API Credentials" 
        
            if (Test-Path $APIcredfile) {
                Write-Output    $Script:strLineSeparator        
                "  Backup API Credential File Present"
                $APIcredentials = get-content $APIcredfile
                
                $Script:cred0 = [string]$APIcredentials[0] 
                $Script:cred1 = [string]$APIcredentials[1]
                $Script:cred2 = $APIcredentials[2] | Convertto-SecureString 
                $Script:cred2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Script:cred2))

                Write-Output    $Script:strLineSeparator 
                Write-output "  Stored Backup API Partner  = $Script:cred0"
                Write-output "  Stored Backup API User     = $Script:cred1"
                Write-output "  Stored Backup API Password = Encrypted"
                
            }else{
                Write-Output    $Script:strLineSeparator 
                Write-Output "  Backup API Credential File Not Present"

                Set-APICredentials  ## Create API Credential File if Not Found
                }
            }

}  ## Get API credentials if present

Function Send-APICredentialsCookie {

Get-APICredentials  ## Read API Credential File before Authentication

$url = "https://api.backup.management/jsonapi"
$data = @{}
$data.jsonrpc = '2.0'
$data.id = '2'
$data.method = 'Login'
$data.params = @{}
$data.params.partner = $Script:cred0
$data.params.username = $Script:cred1
$data.params.password = $Script:cred2

$webrequest = Invoke-WebRequest -Method POST `
    -ContentType 'application/json' `
    -Body (ConvertTo-Json $data) `
    -Uri $url `
    -SessionVariable Script:websession `
    -UseBasicParsing
    $Script:cookies = $websession.Cookies.GetCookies($url)
    $Script:websession = $websession
    $Script:Authenticate = $webrequest | convertfrom-json

#Debug Write-output "$($Script:cookies[0].name) = $($cookies[0].value)"

if ($authenticate.visa) { 

    $Script:visa = $authenticate.visa
    $script:UserId = $authenticate.result.result.id
    }else{
        Write-Output    $Script:strLineSeparator 
        Write-output "  Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials"
        Write-output "  Please Note: Multiple failed authentication attempts could temporarily lockout your user account"
        Write-Output    $Script:strLineSeparator 
        
        Set-APICredentials  ## Create API Credential File if Authentication Fails
    }

}  ## Use Backup.Management credentials to Authenticate

Function Visa-Check {
    if ($Script:visa) {
        $VisaTime = (Convert-UnixTimeToDateTime ([int]$Script:visa.split("-")[3]))
        If ($VisaTime -lt (Get-Date).ToUniversalTime().AddMinutes(-10)){
            Send-APICredentialsCookie
        }
    }
}  ## Recheck remaining Visa time and reauthenticate

#endregion ----- Authentication ----

#region ----- Data Conversion ----
Function Convert-UnixTimeToDateTime($inputUnixTime){
    if ($inputUnixTime -gt 0 ) {
    $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
    $epoch = $epoch.ToUniversalTime()
    $epoch = $epoch.AddSeconds($inputUnixTime)
    return $epoch
    }else{ return ""}
}  ## Convert epoch time to date time 

Function Convert-DateTimeToUnixTime($DateToConvert) {
    $epochdate = Get-Date -Date "1970-01-01 00:00:00Z"
    $NewExtensionDate = Get-Date -Date $DateToConvert
    $NewEpoch = (New-TimeSpan -Start $epochdate -End $NewExtensionDate).TotalSeconds
    Return $NewEpoch
}  ## Convert date time to epoch time

Function Save-CSVasExcel {
    param (
        [string]$CSVFile = $(Throw 'No file provided.')
    )
    
    BEGIN {
        function Resolve-FullPath ([string]$Path) {    
            if ( -not ([System.IO.Path]::IsPathRooted($Path)) ) {
                # $Path = Join-Path (Get-Location) $Path
                $Path = "$PWD\$Path"
            }
            [IO.Path]::GetFullPath($Path)
        }

        function Release-Ref ($ref) {
            ([System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) -gt 0)
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
        
        $CSVFile = Resolve-FullPath $CSVFile
        $xl = New-Object -ComObject Excel.Application
    }

    PROCESS {
        $wb = $xl.workbooks.open($CSVFile)
        $xlOut = $CSVFile -replace '\.csv$', '.xlsx'
        
        # can comment out this part if you don't care to have the columns autosized
        $ws = $wb.Worksheets.Item(1)
        $range = $ws.UsedRange
        [void]$range.AutoFilter()
        [void]$range.EntireColumn.Autofit()

        $num = 1
        $dir = Split-Path $xlOut
        $base = $(Split-Path $xlOut -Leaf) -replace '\.xlsx$'
        $nextname = $xlOut

        <#
        while (Test-Path $nextname) {
            $nextname = Join-Path $dir $($base + "-$num" + '.xlsx')
            $num++
        }
        #>  ## Increment file name

        $xl.DisplayAlerts = $False  ## Block overwrite file warning
        $wb.SaveAs($nextname, 51)
    }

    END {
        $xl.Quit()
    
        $null = $ws, $wb, $xl | ForEach-Object {Release-Ref $_}

        # del $CSVFile
    }
} ## Save as output XLS Routine

#endregion ----- Data Conversion ----

#region ----- Backup.Management JSON Calls ----

Function Send-GetPartnerInfo ($PartnerName) { 
                    
    $url = "https://api.backup.management/jsonapi"
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $Script:visa
    $data.method = 'GetPartnerInfo'
    $data.params = @{}
    $data.params.name = [String]$PartnerName

    $webrequest = Invoke-WebRequest -Method POST `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json $data -depth 5) `
        -Uri $url `
        -SessionVariable Script:websession `
        -UseBasicParsing
        #$Script:cookies = $websession.Cookies.GetCookies($url)
        $Script:websession = $websession
        $Script:Partner = $webrequest | convertfrom-json

    $RestrictedPartnerLevel = @("Root","SubRoot","Distributor")

    if ($Partner.result.result.Level -notin $RestrictedPartnerLevel) {
        [String]$Script:Uid = $Partner.result.result.Uid
        [int]$Script:PartnerId = [int]$Partner.result.result.Id
        [String]$script:Level = $Partner.result.result.Level
        [String]$Script:PartnerName = $Partner.result.result.Name

        Write-Output $Script:strLineSeparator
        Write-output "  $PartnerName - $partnerId - $Uid"
        Write-Output $Script:strLineSeparator
        }else{
        Write-Output $Script:strLineSeparator
        Write-Host "  Lookup for $($Partner.result.result.Level) Partner Level Not Allowed"
        Write-Output $Script:strLineSeparator
        $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
        Send-GetPartnerInfo $Script:partnername
        }

    if ($partner.error) {
        write-output "  $($partner.error.message)"
        $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
        Send-GetPartnerInfo $Script:partnername

    }else{$script:visa = $Partner.visa}

} ## get PartnerID and Partner Level    

Function CallJSON($url,$object) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($object)
    $web = [System.Net.WebRequest]::Create($url)
    $web.Method = "POST"
    $web.ContentLength = $bytes.Length
    $web.ContentType = "application/json"
    $stream = $web.GetRequestStream()
    $stream.Write($bytes,0,$bytes.Length)
    $stream.close()
    $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
    return $reader.ReadToEnd()| ConvertFrom-Json
    $reader.Close()
}

Function Send-EnumeratePartners {
    # ----- Get Partners via EnumeratePartners -----
    
    # (Create the JSON object to call the EnumeratePartners function)
        $objEnumeratePartners = (New-Object PSObject | Add-Member -PassThru NoteProperty jsonrpc '2.0' |
            Add-Member -PassThru NoteProperty visa $Script:visa |
            Add-Member -PassThru NoteProperty method 'EnumeratePartners' |
            Add-Member -PassThru NoteProperty params @{
                                                        parentPartnerId = $PartnerId 
                                                        fetchRecursively = "true"
                                                        fields = (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22) 
                                                        } |
            Add-Member -PassThru NoteProperty id '1')| ConvertTo-Json -Depth 5
    
    # (Call the JSON Web Request Function to get the EnumeratePartners Object)
            [array]$Script:EnumeratePartnersSession = CallJSON $urlJSON $objEnumeratePartners
    
            $Script:visa = $EnumeratePartnersSession.visa
    
            #Write-Output    $Script:strLineSeparator
            #Write-Output    "  Using Visa:" $Script:visa
            #Write-Output    $Script:strLineSeparator
    
    # (Added Delay in case command takes a bit to respond)
            Start-Sleep -Milliseconds 100
    
    # (Get Result Status of EnumerateAccountProfiles)
            $EnumeratePartnersSessionErrorCode = $EnumeratePartnersSession.error.code
            $EnumeratePartnersSessionErrorMsg = $EnumeratePartnersSession.error.message
    
    # (Check for Errors with EnumeratePartners - Check if ErrorCode has a value)
            if ($EnumeratePartnersSessionErrorCode) {
                Write-Output    $Script:strLineSeparator
                Write-Output    "  EnumeratePartnersSession Error Code:  $EnumeratePartnersSessionErrorCode"
                Write-Output    "  EnumeratePartnersSession Message:  $EnumeratePartnersSessionErrorMsg"
                Write-Output    $Script:strLineSeparator
                Write-Output    "  Exiting Script"
    # (Exit Script if there is a problem)
    
                #Break Script
            }else{
    # (No error)
    
            $Script:EnumeratePartnersSessionResults = $EnumeratePartnersSession.result.result | select-object Name,@{l='Id';e={($_.Id).tostring()}},Level,ExternalCode,ParentId,LocationId,* -ExcludeProperty Company -ErrorAction Ignore
            
            $Script:EnumeratePartnersSessionResults | ForEach-Object {$_.CreationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.CreationTime))}
            $Script:EnumeratePartnersSessionResults | ForEach-Object { if ($_.TrialExpirationTime  -ne "0") { $_.TrialExpirationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialExpirationTime))}}
            $Script:EnumeratePartnersSessionResults | ForEach-Object { if ($_.TrialRegistrationTime -ne "0") {$_.TrialRegistrationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialRegistrationTime))}}
        
            $Script:SelectedPartners = $EnumeratePartnersSessionResults | Select-object * | Where-object {$_.name -notlike "001???????????????- Recycle Bin"} | Where-object {$_.Externalcode -notlike '`[??????????`]* - ????????-????-????-????-????????????'}
                    
            $Script:SelectedPartner = $Script:SelectedPartners += @( [pscustomobject]@{Name=$PartnerName;Id=[string]$PartnerId;Level='<ParentPartner>'} ) 
                            
            if ($AllPartners) {
                $script:Selection = $Script:SelectedPartners |Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name
                Write-Output    $Script:strLineSeparator
                Write-Output    "  All Partners Selected"
            }else{
                $script:Selection = $Script:SelectedPartners |Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name | out-gridview -Title "Current Partner | $partnername" -OutputMode Single
        
                if($null -eq $Selection) {
                    # Cancel was pressed
                    # Run cancel script
                    Write-Output    $Script:strLineSeparator
                    Write-Output    "  No Partners Selected"
                    Break
                }else{
                    # OK was pressed, $Selection contains what was chosen
                    # Run OK script
                    [int]$script:PartnerId = $script:Selection.Id
                    [String]$script:PartnerName = $script:Selection.Name
                }
            }
    }
    
}  ## EnumeratePartners API Call

Function Send-GetDevices {
    $url = "https://api.backup.management/jsonapi"
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $script.visa
    $data.method = 'EnumerateAccountStatistics'
    $data.params = @{}
    $data.params.query = @{}
    $data.params.query.PartnerId = [int]$PartnerId
    $data.params.query.Filter = "AT==2"
    $data.params.query.Columns = @("AR","PF","AN","MN","AL","AU","CD","TS","TL","T3","US","TB","T7","TM","D19F21","GM","JM","D5F20","D5F22",  "LN","AA843")
    $data.params.query.OrderBy = "CD DESC"
    $data.params.query.StartRecordNumber = 0
    $data.params.query.RecordsCount = $devicecount
    $data.params.query.Totals = @("COUNT(AT==2)","SUM(T3)","SUM(US)")

    $jsondata = (ConvertTo-Json $data -depth 6)

    $params = @{
        Uri         = $url
        Method      = $method
        Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
        Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
        ContentType = 'application/json; charset=utf-8'
    }  

    $Script:DeviceResponse = Invoke-RestMethod @params 
            
    $Script:DeviceDetail = @()

    ForEach ( $DeviceResult in $DeviceResponse.result.result ) {
        
        $AccountID = [Int]$DeviceResult.AccountId
        Get-AccountInfoById $AccountID

    $Script:DeviceDetail += New-Object -TypeName PSObject -Property @{ AccountID = [Int]$DeviceResult.AccountId;
                                                                PartnerID        = [string]$DeviceResult.PartnerId;
                                                                PartnerName      = $DeviceResult.Settings.AR -join '' ;
                                                                Reference        = $DeviceResult.Settings.PF -join '' ;
                                                                Account          = $DeviceResult.Settings.AU -join '' ;  
                                                                DeviceName       = $DeviceResult.Settings.AN -join '' ;
                                                                ComputerName     = $DeviceResult.Settings.MN -join '' ;
                                                                DeviceAlias      = $DeviceResult.Settings.AL -join '' ;
                                                                Creation         = Convert-UnixTimeToDateTime ($DeviceResult.Settings.CD -join '') ;
                                                                TimeStamp        = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TS -join '') ;  
                                                                LastSuccess      = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TL -join '') ;                                                                                                                                                                                                               
                                                                SelectedGB       = [math]::Round([Decimal](($DeviceResult.Settings.T3 -join '') /1GB),2) ;  
                                                                UsedGB           = [math]::Round([Decimal](($DeviceResult.Settings.US -join '') /1GB),2) ;
                                                                Last28Days       = (($DeviceResult.Settings.TB -join '')[-1..-28] -join '') -replace("8",[char]0x26a0) -replace("7",[char]0x23f9) -replace("6",[char]0x23f9) -replace("5",[char]0x2611) -replace("2",[char]0x274e) -replace("1",[char]0x2BC8) -replace("0",[char]0x274c) ;
                                                                Last28           = (($DeviceResult.Settings.TB -join '')[-1..-28] -join '') -replace("8","!") -replace("7","!") -replace("6","?") -replace("5","+") -replace("2","-") -replace("1",">") -replace("0","X") ;
                                                                Errors           = $DeviceResult.Settings.T7 -join '' ;
                                                                Billable         = $DeviceResult.Settings.TM -join '' ;
                                                                Shared           = $DeviceResult.Settings.D19F21 -join '' ;
                                                                MailBoxes        = $DeviceResult.Settings.GM -join '' ;
                                                                OneDrive         = $DeviceResult.Settings.JM -join '' ;
                                                                SPusers          = $DeviceResult.Settings.D5F20 -join '' ;
                                                                SPsites          = $DeviceResult.Settings.D5F22 -join '' ;
                                                                StorageLocation  = $DeviceResult.Settings.LN -join '' ;
                                                                AccountToken     = $Script:AccountInfoResponse.result.result.Token;
                                                                Notes            = $DeviceResult.Settings.AA843 -join '' }

    }

} ## EnumerateAccountStatistics API Call

Function GetM365Stats {
    Param([Parameter(Mandatory=$true)][Int]$DeviceId) #end param

    $url2 = "https://api.backup.management/c2c/statistics/devices/id/$deviceid"
    $method = 'GET'

    $params = @{
        Uri         = $url2
        Method      = $method
        Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
        WebSession  = $websession
        ContentType = 'application/json; charset=utf-8'
    }   

    $Script:M365response = Invoke-RestMethod @params 

    Write-output  "$url2"

    Get-AccountInfoById $deviceID

    $script:devicestatistics = $M365response.deviceStatistics | Select-object @{N="Partner";E={$device.partnername}},
                                                                                @{N="Account";E={$device.DeviceName}},
                                                                                DisplayName,
                                                                                EmailAddress,
                                                                                Billable,
                                                                                @{N="Shared";E={$_.shared[0] -replace("TRUE","Shared") -replace("FALSE","") }},
                                                                                @{N="MailBox";E={$_.datasources.status[0] -replace("unprotected","") }},
                                                                                @{N="OneDrive";E={$_.datasources.status[1]  -replace("unprotected","")  }},
                                                                                @{N="SharePoint";E={$_.datasources.status[2]  -replace("unprotected","")  }},
                                                                                @{N="UserGuid";E={$_.UserId}},
                                                                                @{N="AccountToken";E={$device.accountToken}} 
                                    

    $script:devicestatistics | foreach-object { if((($_.Mailbox -eq "protected") -and ($_.shared -ne "shared")) -or ($_.OneDrive -eq "protected") -or ($_.SharePoint -eq "protected")) {$_.Billable = "Billable"}} 
    $devicestatistics | Select-object * | format-table
    if ($gridview) {$devicestatistics | out-gridview -title "$($device.partnername) | $($device.DeviceName)" }
} 

Function Get-AccountInfoById ([int]$AccountId) {
    $url = "https://api.backup.management/jsonapi"
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.visa = $Script:Visa
    $data.method = 'GetAccountInfoById'
    $data.params = @{}
    $data.params.accountId = [int]$AccountId

    $jsondata = (ConvertTo-Json $data -depth 6)

    $params = @{
        Uri         = $url
        Method      = $method
        Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
        Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
        WebSession  = $websession
        ContentType = 'application/json; charset=utf-8'
    }   

    $Script:AccountInfoResponse = Invoke-RestMethod @params 
}

Function EnumerateM365Users ($AccountToken) {
    $url = "https://api.backup.management/management_api"
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'EnumerateUsers'
    $data.params = @{}
    $data.params.accountToken = $accountToken

    $jsondata = (ConvertTo-Json $data -depth 6)

    $params = @{
        Uri         = $url
        Method      = $method
        Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
        Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
        WebSession  = $websession
        ContentType = 'application/json; charset=utf-8'
        TimeoutSec  = 10000
    }   

    $Script:EnumerateM365UsersResponse = Invoke-RestMethod @params 

    $script:M365UserStatistics = $EnumerateM365UsersResponse.result.result.Users | Select-object @{N="Partner";E={$device.partnername}},
                                                                                                @{N="Account";E={$device.DeviceName}},
                                                                                                DisplayName,
                                                                                                EmailAddress,
                                                                                                @{N="MailBoxSelection";E={$_.ExchangeInfo.Selection}},
                                                                                                @{N="MailBoxStatus";E={$_.ExchangeInfo.MailboxType}},
                                                                                                @{N="New";E={$_.IsNew[0] -replace("True","New") -replace("False","") }},
                                                                                                @{N="Deleted";E={$_.IsDeleted[0] -replace("True","Deleted") -replace("False","") }},
                                                                                                @{N="Shared";E={$_.IsShared[0] -replace("True","Shared") -replace("False","") }},
                                                                                                @{N="MailBoxLastBackupStatus";E={$_.ExchangeInfo.LastBackupStatus}},
                                                                                                @{N="MailBoxLastBackupTimestamp";E={Convert-UnixTimeToDateTime ($_.ExchangeInfo.LastBackupTimestamp)}},
                                                                                                @{N="ExchangeAutoInclude";E={$Script:EnumerateM365UsersResponse.result.result.ExchangeAutoInclusionType}},
                                                                                                @{N="OneDriveSelection";E={$_.OneDriveInfo.Selection}},
                                                                                                @{N="OneDriveStatus";E={$_.OneDriveInfo.LicenseStatus}},
                                                                                                @{N="OneDriveSelectedGib";E={[math]::Round([Decimal](($_.OneDriveInfo.SelectedSize) /1GB),3) }},
                                                                                                @{N="OneDriveLastBackupStatus";E={$_.OneDriveInfo.LastBackupStatus}},
                                                                                                @{N="OneDriveLastBackupTimestamp";E={Convert-UnixTimeToDateTime ($_.OneDriveInfo.LastBackupTimestamp)}},
                                                                                                @{N="OneDriveAutoInclude";E={$Script:EnumerateM365UsersResponse.result.result.OneDriveAutoInclusionType}},
                                                                                                UserGuid,
                                                                                                @{N="AccountToken";E={$accounttoken}} 

    $Script:M365UserStatistics | Select-object * | format-table
    if ($gridview) {$Script:M365UserStatistics | out-gridview -title "$($device.partnername) | $($device.DeviceName)" }
}

Function Join-Reports {
    if (Get-Module -ListAvailable -Name Join-Object) {
        Write-Host "Module Join-Object Already Installed"
    } 
    else {
        try {
            Install-Module -Name Join-Object   -Confirm:$True -Force
        }
        catch [Exception] {
            $_.message
            Write-Warning "PS Module 'Join-Object' not found, run with Administrator rights to install" 
            exit
        }
    }

    $Script:M365Users = Join-Object -left $script:M365UserStatistics -LeftJoinProperty UserGuid -right $script:devicestatistics -RightJoinProperty UserGuid -Prefix 'Protected_' -Type AllInLeft -RightProperties Billable,Mailbox,OneDrive,SharePoint

    $Script:M365UserStatistics = $Script:M365Users | Select-Object  Partner,
                                                                    Account,
                                                                    DisplayName,
                                                                    EmailAddress,
                                                                    Protected_Billable,
                                                                    New,
                                                                    Deleted,
                                                                    Shared,
                                                                    Protected_Mailbox,
                                                                    MailBoxSelection,
                                                                    MailBoxStatus,
                                                                    MailBoxLastBackupStatus,
                                                                    MailBoxLastBackupTimestamp,
                                                                    ExchangeAutoInclude,
                                                                    Protected_OneDrive,
                                                                    OneDriveSelection,
                                                                    OneDriveStatus,
                                                                    OneDriveSelectedGib,
                                                                    OneDriveLastBackupStatus,
                                                                    OneDriveLastBackupTimestamp,
                                                                    OneDriveAutoInclude,
                                                                    Protected_SharePoint,
                                                                    UserGuid,
                                                                    AccountToken	
}

Function Remove-BackupHistory ($dataSourceType,$accounttoken,$UserGuid) {

    $url = "https://api.backup.management/management_api"
    $method = 'POST'
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'RemoveBackup'
    $data.params = @{}
    $data.params.accountToken = $AccountToken
    $data.params.dataSourceType = $dataSourceType
    $data.params.entityId = $UserGuid

    $jsondata = (ConvertTo-Json $data -depth 6)

    $params = @{
        Uri         = $url
        Method      = $method
        Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
        Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
        ContentType = 'application/json; charset=utf-8'
    }  

    $Script:RemovedOneDriveHistory = Invoke-RestMethod @params 

    $Script:RemovedOneDriveHistory.error.message
        
}

Function ExitRoutine {
    Write-Output $Script:strLineSeparator
    Write-Output "  Secure credential file found here:"
    Write-Output $Script:strLineSeparator
    Write-Output "  & $APIcredfile"
    Write-Output ""
    Write-Output $Script:strLineSeparator
    Start-Sleep -seconds 3
    }

#endregion ----- Backup.Management JSON Calls ----

#endregion ----- Functions ----

    Send-APICredentialsCookie

    Write-Output $Script:strLineSeparator
    Write-Output "" 

    Send-GetPartnerInfo $Script:cred0

    if ($AllPartners) {}else{Send-EnumeratePartners}

    Send-GetDevices $partnerId

    if ($AllDevices) {
        $script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,AccountID,DeviceName,SelectedGB,UsedGB,Last28Days,Errors,Billable,MailBoxes,Shared,OneDrive,SPusers,SPsites,StorageLocation,TimeStamp,LastSuccess,Creation,AccountToken,Notes
    }else{
        $script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,AccountID,DeviceName,SelectedGB,UsedGB,Last28Days,Errors,Billable,MailBoxes,Shared,OneDrive,SPusers,SPsites,StorageLocation,TimeStamp,LastSuccess,Creation,AccountToken,Notes  | Out-GridView -title "Current Partner | $partnername" -OutputMode Multiple}
        Visa-Check
    if ($null -eq $SelectedDevices) {
        # Cancel was pressed
        # Run cancel script
        Write-Output    $Script:strLineSeparator
        Write-Output    "  No Devices Selected"
        Break
    }else{
        # OK was pressed, $Selection contains what was chosen
        # Run OK script
        $DeviceDetail | Select-Object PartnerId,PartnerName,AccountID,DeviceName,SelectedGB,UsedGB,Last28,Errors,Billable,MailBoxes,Shared,OneDrive,SPusers,SPsites,StorageLocation,TimeStamp,LastSuccess,Creation,Notes  | Sort-object PartnerName,AccountId | format-table

        If ($Script:Exportcombined) {
            $Script:csvoutputfile = "$ExportPath\$($CurrentDate)_M365_Devices_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"
            $SelectedDevices | Select-object * | Export-CSV -Delimiter $delimiter -path "$csvoutputfile" -NoTypeInformation -Encoding UTF8}
            
    }

    foreach ($device in $SelectedDevices) {
        GetM365Stats $Device.AccountID
        EnumerateM365Users $device.AccountToken
        join-reports
        
        If ($Exportcombined) {
            $Script:csvoutputfile2b = "$ExportPath\$($CurrentDate)_M365_User_Export_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"
            $Script:M365UserStatistics | Select-object * | Export-CSV -Delimiter $delimiter -path "$csvoutputfile2b" -NoTypeInformation -Encoding UTF8 -append
        }

        If ($csvoutputfile3b) {
            $xlsoutputfile3b = $csvoutputfile3b.Replace("csv","xlsx")
            Save-CSVasExcel $csvoutputfile3b
        }

        If ($csvoutputfile4) {
            $xlsoutputfile4 = $csvoutputfile4.Replace("csv","xlsx")
            Save-CSVasExcel $csvoutputfile4
        }
    }

    ## Generate XLS from CSV
    
    if ($csvoutputfile) {
        $xlsoutputfile = $csvoutputfile.Replace("csv","xlsx")
        Save-CSVasExcel $csvoutputfile
    }

    If ($csvoutputfile2b) {
        $xlsoutputfile2b = $csvoutputfile2b.Replace("csv","xlsx")
        Save-CSVasExcel $csvoutputfile2b
    }

    Write-output $Script:strLineSeparator

    ## Launch CSV or XLS if Excel is installed  (Required -Launch Parameter)
        
    if ($ExportSharedBillable) {
        $SharedBillable = Import-Csv $Script:csvoutputfile2b
        $filterdate1 = (Get-Date).AddDays(-$OneDriveAge)
        $Script:csvoutputfile2bs = "$ExportPath\$($CurrentDate)_M365_User_Export_Shared_Billable_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"
        $SharedBillable | Where-Object {($_.shared -eq "Shared") -and ($_.Protected_Billable -eq "Billable") -and ([datetime]$_.OneDriveLastBackupTimestamp -lt $filterdate1)} | Export-Csv -Path $csvoutputfile2bs -NoTypeInformation

        Write-output $Script:strLineSeparator
        Write-Output "  CSV Path = $Script:csvoutputfile2bs"
        Write-output $Script:strLineSeparator

        if ($CleanupSharedBillable) {
            $Script:OneDriveToClean = $SharedBillable | Where-Object {($_.shared -eq "Shared") -and ($_.Protected_Billable -eq "Billable") -and ([datetime]$_.OneDriveLastBackupTimestamp -lt $filterdate1)} | Out-GridView -Title "Billable Shared Mailboxes Due to Historic OneDrive Retention > $OneDriveAge days | Select Accounts to Purge OneDrive Backup History" -OutputMode Multiple

            foreach ($item in $OneDriveToClean) {
                visa-check
                Write-output "Attempting OneDrive removal for Shared Mailbox $($item.accounttoken) $($item.UserGuid) $($item.emailAddress)"
                Remove-BackupHistory "OneDrive" $item.accounttoken $item.UserGuid
            }
        }
    }

    if ($ExportDeleted) {
        $Deleted = Import-Csv $Script:csvoutputfile2b
        $filterdate2 = (Get-Date).AddDays(-$DeletedAge)
        $Script:csvoutputfile2bd = "$ExportPath\$($CurrentDate)_M365_User_Export_Deleted_Shared_Billable_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"
        $Deleted | Where-Object {($_.deleted -eq "Deleted") -and ([datetime]$_.MailBoxLastBackupTimestamp -lt $filterdate2)} | Export-Csv -Path $csvoutputfile2bd -NoTypeInformation
        
        Write-output $Script:strLineSeparator
        Write-Output "  CSV Path = $Script:csvoutputfile2bd"
        Write-output $Script:strLineSeparator
        
        if ($CleanupDeleted) {
            $Script:DeletedToClean = $Deleted | Where-Object {($_.deleted -eq "Deleted") -and ([datetime]$_.MailBoxLastBackupTimestamp -lt $filterdate2)} |Out-GridView -Title "Deleted Mailboxes with Retention > $DeletedAge days | Select Accounts to Purge Backup History" -OutputMode Multiple

            foreach ($item in $DeletedToClean) {
                visa-check
                Write-output "Attempting removal for Deleted Mailbox$($item.accounttoken) $($item.UserGuid) $($item.emailAddress)"
                Remove-BackupHistory "Exchange" $item.accounttoken $item.UserGuid
                Remove-BackupHistory "OneDrive" $item.accounttoken $item.UserGuid
            }
        }
    }

    if ($Launch -and $ExportCombined) {
        If (test-path HKLM:SOFTWARE\Classes\Excel.Application) { 
            Start-Process "$xlsoutputfile"
            #Start-Process "$xlsoutputfile2a"
            Start-Process "$xlsoutputfile2b"
            Write-output $Script:strLineSeparator
            Write-Output "  Opening XLS file"
            }else{
            Start-Process "$csvoutputfile"
            #Start-Process "$csvoutputfile2a"
            Start-Process "$csvoutputfile2b"
            Write-output $Script:strLineSeparator
            Write-Output "  Opening CSV file"
            Write-output $Script:strLineSeparator            
            }
    }

    If ($Exportcombined) {
        Write-output $Script:strLineSeparator
        Write-Output "  CSV Path = $Script:csvoutputfile"
        #Write-Output "  CSV Path = $Script:csvoutputfile2a"
        Write-Output "  CSV Path = $Script:csvoutputfile2b"
        Write-Output "  XLS Path = $Script:xlsoutputfile"
        #Write-Output "  XLS Path = $Script:xlsoutputfile2a"
        Write-Output "  XLS Path = $Script:xlsoutputfile2b"
        Write-Output ""
    }
    

    ExitRoutine
  