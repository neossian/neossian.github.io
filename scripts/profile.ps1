<<<<<<< Updated upstream
$ProfileVersion = "1.67"
=======
$ProfileVersion = "1.69"
>>>>>>> Stashed changes
$ErrorActionPreference = 'SilentlyContinue'
Write-output "Loading version $ProfileVersion"
<#
 md (split-path $profile.CurrentUserAllHosts) -ea 0 | out-null
 notepad $profile.currentUserallhosts
 . $profile.currentuserallhosts

md (split-path $profile.CurrentUserAllHosts) -ea 0 | out-null
 invoke-webrequest http://www.wrish.com/scripts/profile.ps1 -outfile $profile.currentuserallhosts 
  . $profile.currentuserallhosts
#>

function TryCopyProfile {
    #Stab this into my profile
    md (split-path $profile.CurrentUserAllHosts) -ea 0 | out-null
    invoke-webrequest http://www.wrish.com/scripts/profile.ps1 -outfile $profile.currentuserallhosts 
    . $profile.currentuserallhosts
}

function get-MemberofBigGroup ($GroupDN){
     
    $directorySearcher = New-Object System.DirectoryServices.DirectorySearcher
    $groupDomain = (((($groupDN -split ',')|?{$_ -match '^DC='}) -join ',') -replace ',DC=','.') -replace  'DC=',''
    $directorySearcher.SearchRoot = [ADSI]"LDAP://$groupDomain/$GroupDN"
    $directorySearcher.Filter = '(objectClass=*)'
    [void]$directorySearcher.PropertiesToLoad.Add('cn')
    [void]$directorySearcher.PropertiesToLoad.Add('distinguishedname')
    [void]$directorySearcher.PropertiesToLoad.Add('member')
    $results = $directorySearcher.FindOne()

    
    if ($pageProperty = $results.Properties.PropertyNames.Where({$psitem -match '^member;range'}) -as [String]) {
        $directoryEntry = $results.Properties.adspath -as [String]
        $increment = $results.Properties.$pageProperty.count -as [Int]
        $results.Properties.$pageProperty
        $start = $increment
        do {
            $end = $start + $increment - 1            
            $memberProperty = 'member;range={0}-{1}' -f $start,$end
            Write-Verbose "Getting $memberProperty"
            $memberPager = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList $directoryEntry,'(objectClass=*)',$memberProperty,'Base'
            $pageResults = $memberPager.FindOne()
            $pageProperty = $pageResults.Properties.PropertyNames.Where({$psitem -match '^member;range'}) -as [String]
            $pageResults.Properties.$pageProperty
            $start = $end + 1
        } until ( $pageProperty -match '^member.*\*$' )
    }
    else {
        $results.member
    }
}

function Get-ADGroupMemberxDomain 
{
    [CmdletBinding()]
    Param(  [parameter(ValueFromPipelineByPropertyName)][alias("distinguishedName")]$groupDN, [switch]$recursive, $listSoFar, $recurseLevel=0)
    
    $groupDomain = (((($groupDN -split ',')|?{$_ -match '^DC='}) -join ',') -replace ',DC=','.') -replace  'DC=',''
    $Group = [ADSI]("LDAP://$GroupDomain/" + $groupDN)
    $memberlist = $Group.member
    if ($memberlist.count -eq 1500){
        $memberlist = get-MemberofBigGroup -GroupDN $groupDN
    }
    if ($memberlist){
        if($recursive){ Write-Verbose "Recursion Level $recurseLevel - under $groupDN"}
        $memberlist
    }
    if ($recursive) {
        foreach ($member in $memberlist){
            if ($listSoFar -notcontains $member){
                Get-adgroupMemberxDomain $member -recursive ([array]$listsofar + $memberlist) ($recurseLevel+1)
            }   
        }
    }
}


function remove-ADGroupMemberxDomain ($userDN, $groupDN){
    $userDomain = (((($userDN -split ',')|?{$_ -match '^DC='}) -join ',') -replace ',DC=','.') -replace  'DC=',''
    $groupDomain = (((($groupDN -split ',')|?{$_ -match '^DC='}) -join ',') -replace ',DC=','.') -replace  'DC=',''
    $User = [ADSI]("LDAP://$userDomain/" + $UserDN)
    $Group = [ADSI]("LDAP://$GroupDomain/" + $groupDN)
    try {        
        $Group.Remove($User.ADsPath)
        Write-Verbose "Successfully removed $userDN from $groupDN"
    } catch {
        write-error "Unable to remove $UserDN from $groupDN because $_"
    }
}



function Add-ADGroupMemberxDomain ($userDN, $groupDN){
    $userDomain = (((($userDN -split ',')|?{$_ -match '^DC='}) -join ',') -replace ',DC=','.') -replace  'DC=',''
    $groupDomain = (((($groupDN -split ',')|?{$_ -match '^DC='}) -join ',') -replace ',DC=','.') -replace  'DC=',''
    $User = [ADSI]("LDAP://$userDomain/" + $UserDN)
    $Group = [ADSI]("LDAP://$GroupDomain/" + $groupDN)
    try {        
        $Group.Add($User.ADsPath)
        Write-Verbose "Successfully added $userDN to $groupDN"
    } catch {
        write-error "Unable to add $UserDN to $groupDN because $_"
    }
}

#https://superuser.com/questions/1196477/allow-users-to-change-expired-password-via-remote-desktop-connection
function Change-Password {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $UserName,
        [Parameter(Mandatory = $true)][string] $OldPassword,
        [Parameter(Mandatory = $true)][string] $NewPassword,
        [Parameter(Mandatory = $true)][alias('DC', 'Server', 'ComputerName')][string] $DomainController
    )
    $DllImport = @'
[DllImport("netapi32.dll", CharSet = CharSet.Unicode)]
public static extern bool NetUserChangePassword(string domain, string username, string oldpassword, string newpassword);
'@
    $NetApi32 = Add-Type -MemberDefinition $DllImport -Name 'NetApi32' -Namespace 'Win32' -PassThru
    if ($result = $NetApi32::NetUserChangePassword($DomainController, $UserName, $OldPassword, $NewPassword)) {
        Write-Output -InputObject 'Password change failed. Please try again.'
    } else {
        Write-Output -InputObject 'Password change succeeded.'
    }
}

function Get-OctetStringFromGuid
{
    [CmdletBinding()]
    param
    (
        [System.Guid]
        $GuidToConvert
    )
    
    return ("\" + ([System.String]::Join('\', ($GuidToConvert.ToByteArray() | ForEach-Object { $_.ToString('x2') }))));   
}

function get-ldapData ($ldapfilter,$searchRoot,$Server,$searchScope='subtree',[switch]$GC,$objectGuid,$Enabled,$passwordNotRequired,$CannotChangePassword,$PasswordNeverExpires,$TrustedForDelegation,$DontRequirePreauth,$O365Find,$pageSize=1000,$Properties="*",$sizeLimit=0,[switch]$verbose,[switch]$includeDeletedObjects){
<#
.DESCRIPTION
Wrapper for the LDAP searcher that allows easy searching on any attribute using a parameter

.PARAMETER LDAPFilter
Enter any standard LDAP filter here eg "|(objectclass=user)(objectclass=computer)". Note that any

.PARAMETER SearchRoot
The base to start searching from, by default this is the root of the domain. If the GC is selected this will be the root of the forest. eg CN=users,DC=contoso,dc=com

.PARAMETER Server
Enter a server and/or port eg Test.mydomain.com:389. Only cleartext ports are supported with this version of the tool.

.PARAMETER GC
Enable this switch to automatically search from the root of the forest and search the global catalog. Be aware that the global catalog does not contain a full set of attribute data.

.PARAMETER pageSize
PageSize sets the number of records to be returned in a single connection to the server, a lower page size will return results quicker for a small number of results.

.PARAMETER Sizelimit
The maximum number of records to return - 0 for unlimited

.PARAMETER verbose
Provide verbose output

.Parameter Properties
Select specific ldap properties to be returned, by default all properties are returned.

.EXAMPLE 
get-ldapdata

Return all data for all objects in the current domain

.EXAMPLE 
get-ldapdata -GC -extensionAttribute10 *

Search the the global catalog from the root of the forest for any object with extensionattribute10 set to any value

.EXAMPLE 
get-ldapdata -givenName Joe -sn Smith -objectclass user -gc

Search the global catalog for any user object with a given name = Joe and Lastname equal Smith

.INFO
Version 1.1 Updated to resolve exchange guids, objectSids and process useraccountcontrolflags
Version 1.2 updated to add referral chasing
Version 1.3 updated to add some additional UAC filters

#>

    $useraccountControls = @{
    "UAC-SCRIPT"="1"
    "UAC-Disabled"="2"
    "UAC-HomeDirRequired"="8"
    "UAC-AccountLocked"="16"
    "UAC-PasswordNotRequired"="32"
    "UAC-CannotChangePassword"="64"
    "UAC-EncryptedPasswordAllowed"="128"
    "UAC-TempDuplicateAccount"="256"
    "UAC-NormalAccount"="512"
    "UAC-InterDomainTrustAccount"="2048"
    "UAC-WorkstationTrustAccount"="4096"
    "UAC-ServerTrustAccount"="8192"
    "UAC-PasswordNeverExpires"="65536"
    "UAC-MNS_LOGON_ACCOUNT"="131072"
    "UAC-SmartCardRequired"="262144"
    "UAC-TrustedForDelegation"="524288"
    "UAC-NotDelegated"="1048576"
    "UAC-USE_DES_KEY_ONLY"="2097152"
    "UAC-DONT_REQ_PREAUTH"="4194304"
    "UAC-PasswordExpired"="8388608"
    "UAC-TRUSTED_TO_AUTH_FOR_DELEGATION"="16777216"
    "UAC-PARTIAL_SECRETS_ACCOUNT"="67108864"
    }
    
    if ($server){ $server = "/$Server"}
          
    if ($verbose) {
        $VerbosePreference = "Continue"
    }

    
    if($O365Find){
        $ldapfilter += "(|(userprincipalname=$o365Find)(proxyaddresses=SMTP:$O365Find)(mail=$O365Find)(msrtcsip-primaryuseraddress=sip:$O365Find)(proxyaddresses=SIP:$O365Find)(msrtcsip-primaryuseraddress=SIP:$O365Find))"
        $GC = $true;
    }

    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    } elseif ($args) {
        #args declared, set filter to nothing
        $ldapfilter = ""
    } else {
        #no filter declared, get everything
        $ldapfilter = "(objectclass=*)"
    }
    
    $Root = [ADSI]"LDAP:/$server/RootDSE"

    if ($GC) {
        $protocol = "GC:"        
    } else {
        $protocol = "LDAP:"
    }

    if (!$searchRoot -and $GC){
        $Searchroot  = $root.rootDomainNamingContext
    } elseif (!$searchRoot) {
        $searchroot = $root.defaultnamingContext
    }

    #LDAP arbitrary Searcher
    $attributeName= ""
    for ($i=0;$i -lt $args.count;$i+=2){
         $ldapfilter += "($($args[$i] -replace '^-','')=$(if ($args[$i+1]){$args[$i+1]}else {'*'}))"
    }
    #Process useraccountcontrol searches
    switch ($enabled) {
        $true {$ldapfilter += "(!UserAccountControl:1.2.840.113556.1.4.803:=2)"}
        $false {$ldapfilter += "(UserAccountControl:1.2.840.113556.1.4.803:=2)"}
    }
    switch ($passwordnotrequired) {
        $true {$ldapfilter += "(UserAccountControl:1.2.840.113556.1.4.803:=32)"}
        $false {$ldapfilter += "(!UserAccountControl:1.2.840.113556.1.4.803:=32)"}
    }
    switch ($CannotChangePassword) {
        $true {$ldapfilter += "(UserAccountControl:1.2.840.113556.1.4.803:=64)"}
        $false {$ldapfilter += "(!UserAccountControl:1.2.840.113556.1.4.803:=64)"}
    }
    switch ($PasswordNeverExpires) {
        $true {$ldapfilter += "(UserAccountControl:1.2.840.113556.1.4.803:=65536)"}
        $false {$ldapfilter += "(!UserAccountControl:1.2.840.113556.1.4.803:=65536)"}
    }
    switch ($TrustedForDelegation) {
        $true {$ldapfilter += "(UserAccountControl:1.2.840.113556.1.4.803:=524288)"}
        $false {$ldapfilter += "(!UserAccountControl:1.2.840.113556.1.4.803:=524288)"}
    }
    switch ($DontRequirePreauth) {
        $true {$ldapfilter += "(UserAccountControl:1.2.840.113556.1.4.803:=4194304)"}
        $false {$ldapfilter += "(!UserAccountControl:1.2.840.113556.1.4.803:=4194304)"}
    }
    
    if ($objectGuid){
        switch ($objectGuid.GetType().tostring()){
            'System.Guid'{
                break;        
            }
            'System.String'{
                try {
                    $objectGuid = ([guid]([system.convert]::FromBase64String($objectGuid)))
                    break;
                } catch {
                    write-error 'objectGuid must be either base64 encoded string or system guid';return;
                }                    
            }
            default:{write-error 'objectGuid must be either base64 encoded string or system guid';return;}
        }
        $ldapfilter +="(objectGuid=$(Get-OctetStringFromGuid $objectGuid))"
    }

    $ldapfilter = "(&$ldapfilter)"
    Write-Verbose "Filter being used $ldapfilter"
    
    
    #Connect to the Domain and setup the searcher
    $AdSearcher = [adsisearcher]$ldapfilter
    $AdSearcher.Searchroot = [ADSI]("$protocol/$Server/$Searchroot")
    Write-Verbose ("Searchroot: " + $ADSearcher.SearchRoot.path.tostring())
    $ADSearcher.PageSize = $pageSize
    $adsearcher.searchscope = $searchscope
    $ADSearcher.Sizelimit = $sizeLimit
    $adsearcher.ReferralChasing = [DirectoryServices.ReferralChasingOption]::All    
    $properties | %{$ADSearcher.PropertiesToLoad.Add($_) | out-null}   
    if ($includeDeletedObjects){
        $control = New-Object System.DirectoryServices.Protocols.ShowDeletedControl
        $adsearcher.controls = $control
    }
    #perform the search and process the objects
    foreach ($LDAPResult in $ADSearcher.Findall()){
        $LDAPObject = new-object psobject

        foreach ($property in ($LDAPResult.properties.get_propertyNames())){
            $PropertyValue = $null           
            switch -regex ($property) {
                    'msds-registered(owner|users)'{
                            #ByteString represented SID values
                           $UserList = @()
                           #Registered owners/users are stored as a char representation of the SID value
                           foreach ($ByteSid in $LDAPResult.properties.$property){
                                $stringSid = [System.Text.Encoding]::ASCII.getstring($ByteSid)  
                                $SIDValue = New-Object System.Security.Principal.SecurityIdentifier($stringSid)                                 
                                try{
                                    $StringRep = $SIDValue.Translate([System.Security.Principal.NTAccount])                                   
                                }
                                catch{
                                    $StringRep = $SIDValue
                                }
                                $UserList += $stringRep                                                               
                            }
                            if ($userlist.count -eq 1) {$PropertyValue = $userlist[0]} else {$PropertyValue = $userlist}

                    }                    
                    'objectguid|msds-(deviceid|cloudAnchor)|msexcharchiveguid|msexchmailboxguid'{
                            #GUID Properties 
                            $ValueList = @()
                            foreach ($Value in $LDAPResult.properties.$property){  
                                $ValueList += [guid]$value
                               }
                               if ($ValueList.count -eq 1) {$PropertyValue = $ValueList[0]} else {$PropertyValue = $ValueList}
                    }
                     'objectsid'{                                
                            $SidValue = [byte[]]($ldapresult.properties.$property[0])                                                   
                            $PropertyValue = New-Object System.Security.Principal.SecurityIdentifier($SIDValue,0)        
                    } 
                    'tokenGroups'{                                
                          $PropertyValue =  $ldapresult.properties.$property | %{New-Object System.Security.Principal.SecurityIdentifier([byte[]]$_,0)  }                    
                    } 
                     'badpasswordtime|lastlogontimestamp|lockouttime|pwdlastset|accountexpires|^when|^lastlogon$'{
                        try {
                            if ($ldapresult.properties.$property[0] -ne 9223372036854775807 -and $ldapresult.properties.$property[0] -ne 0) {
                                $PropertyValue =   [datetime]::fromfiletime($LDAPResult.properties.$property[0])
                            } else {
                                $PropertyValue = "never"
                            }
                        } catch {
                            if (($LDAPResult.properties.$property | measure).count -le 1){$PropertyValue = $LDAPResult.properties.$property[0]} else {$PropertyValue = $LDAPResult.properties.$property}
                        }
                     }
                     'UserAccountControl'{                           
                            $UACValue =   $LDAPResult.properties.$property[0]
                            $PropertyValue = $UacValue
                            $useraccountControls.GetEnumerator() | %{
                                if ($uacValue -band $_.value){
                                    $LDAPObject | Add-Member -name $_.name -value $true -Membertype NoteProperty -force
                                } else {
                                    $LDAPObject | Add-Member -name $_.name -value $false -Membertype NoteProperty -force
                                }
                            }
                            
                    }                    

                    default{
                        #remove ugly arrays
                        if (($LDAPResult.properties.$property | measure).count -le 1){$PropertyValue = $LDAPResult.properties.$property[0]} else {$PropertyValue = $LDAPResult.properties.$property}
                    }
            }
            #pin the property to the object
            $LDAPObject | add-member -name $property -value $PropertyValue -MemberType NoteProperty
        }
        write-output $LDAPObject
    }
}

function get-netstatData([switch]$returnProcesses){
	$result = netstat -anob
	$data = @()
	switch -regex ($result){
		'(?<Protocol>TCP|UDP)\s+(?<LocalIP>\d+\.\d+\.\d+\.\d+|\*):(?<LocalPort>\d+|\*)\s+(?<RemoteIP>\d+\.\d+\.\d+\.\d+|\*):(?<RemotePort>\d+|\*)\s+(?<State>\w+|\s)\s+(?<ProcessID>\d+)'{
		   $data += new-object psobject -Property $matches
		}
	}
	return $data | select Protocol,LocalIP,LocalPort,RemoteIP,RemotePort,ProcessID,State,@{l='Process';e={
        if ($returnProcesses -and $_.processID){
            get-process -id $_.processID

        }
    }}
}

function Refresh-ComputerGroupMembership {
    klist -li 0x3e7 purge
}


function Import-SVCLog {
 [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True)]
        [string[]]$FileName
    )    
    Process {
       ([xml]("<LogRoot>" + (get-content $fileName) + "</LogRoot>" )).LogRoot.e2etraceevent | %{            
            $_ | select @{l='EventID';e={$_.system.EventID}},@{l='Type';e={$_.system.Type}},@{l='TimeCreated';e={$_.system.TimeCreated.SystemTime}},@{l='Source';e={$_.system.Source.Name}},@{l='Correlation';e={$_.system.Correlation.activityID}},@{l='Computer';e={$_.system.Computer}},@{l='Info';e={$_.ApplicationData}},@{l='XMLData';e={$_}}                       
       }
    }
}

function Schedule-Restart ($ondatetime,$hour,$minute,$day,$inHours,$inMinutes,$inDays){
    $date = $null
    if ($ondatetime) {
        
        $date = $ondatetime
    } elseif ($hour -ne $null -or $minute -ne $null -or $day -ne $null) {
        $DateParams = $MyInvocation.BoundParameters 
        $dateParams.Remove('ondatetime')|out-null;$dateParams.Remove('inHours')|out-null;$dateParams.Remove('inMinutes')|out-null
        $date = get-date @dateParams
        if ($date -lt (get-date)) {$date = $date.addhours(24)}
    } else {
        $date = get-date
    }
    if ($inhours){$date = $date.addhours($inhours)}
    if ($inMinutes){$date = $date.AddMinutes($inMinutes)}
    if ($inDays){$date = $date.AddDays($inDays)}
    Write-verbose "Date chosen to restart is ($($date.tostring('f')))"
    Write-verbose "Scheduled Task command is [schtasks /Create /RU `"NT AUTHORITY\SYSTEM`" /SC ONCE /st $(($date).tostring('HH:mm')) /TN My-ScheduledRestart /RL HIGHEST /TR `"%windir%\system32\Shutdown.exe /r /t 10`" /SD $(($date).tostring($([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortDatePattern).replace('M+', 'MM').replace('d+', 'dd')))]"
    schtasks /Create /RU "NT AUTHORITY\SYSTEM" /SC ONCE /st $(($date).tostring('HH:mm')) /TN My-ScheduledRestart /RL HIGHEST /TR "%windir%\system32\Shutdown.exe /r /t 10" /SD $(($date).tostring($([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortDatePattern).replace('M+', 'MM').replace('d+', 'dd')))
}

function list-ProfileFunctions ($regex='^###########$') {
    get-content $profile.currentuserAllhosts | select-string "^function|^New-Alias" |%{$_ -replace '^function|^New-Alias','' -replace '\{.*',''}| sort | ho $regex
}
New-Alias lf list-ProfileFunctions
Write-HOst lf list-ProfileFunctions



#Get a new Secure Credential and store it in encrypted format to a file
Function Stored-Credential($name, [switch]$New, [switch]$check, $userName="")
{
   $pathToCred = $env:userprofile + "\$name.securecredential"
    if ($check) {
        return test-path $pathToCred;
    }
    #Check to see if the credential already exists    
    if ((test-path $pathToCred) -and !($new))
    {
        $XMLCredential = Import-cliXML $pathToCred;
        Return  New-Object System.Management.Automation.PsCredential($XMLCredential.user,($XMLCredential.password | ConvertTo-SecureString))    
    } else
    {
        #Get the credential from the user
        $Credential = get-credential -Message "Enter credential to be stored for $name" -UserName $username;
        
        #Create a simple object
        $XMLCredential = new-object psobject -Property @{
             "user"=$credential.username;
             "password"=($credential.password | ConvertFrom-SecureString );           
        }
        $XMLCredential | export-clixml -Path $pathToCred        
        return $Credential
    }        
}

function Connect-Exchange ($Server,[pscredential]$UserCredential,[switch]$list,$version,$site)
{
    if ($server -eq $null){        
        $search = new-object adsisearcher -ArgumentList ([adsi]"LDAP://$(([adsi]"LDAP://rootdse").configurationNamingContext)"), "(&(objectclass=msExchPowerShellVirtualDirectory)(msexchinternalhostname=*))",@("msExchVersion","msExchInternalHostName","distinguishedname")
        $num=0;
        $PSDir =  $search.findall() | sort -descending {$_.properties.msexchversion[0]}  |%{
            
            $vdir = new-object psobject -Property @{num=$null;path=$_.properties.msexchinternalhostname[0];server=$null;Site=$null;version=$null}
            if ($list -or $version -or $site){
                $ServerPath = ($_.properties.distinguishedname[0] -split ",")[3..100] -join ","
                $Serverobj = [adsi]"LDAP://$serverPath"                
                $vdir.version = $serverObj.serialnumber[0]
                $vdir.server = $serverobj.name[0]
                $vdir.Site = $serverobj.msExchServerSite[0] -replace '^CN=|,.*$',''
            }
            $vdir
        }
        $session = $null
        if ($list -or $version -or $site){
            while (!$session)
            { 
                $num = 0
                $PSDir | ?{$list -or ($version -and $_.version -match $version) -or ($site -and $_.site -match $site)} | %{$_.num = $num;$num++; $_} | select Num,Server,Version,Site | ft -AutoSize
                $chosen = read-host "Ctrl+C to cancel or enter a number 0 to $($num -1) to select a server"
                try {
                        if ($usercredential){
                            $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri ($psdir| ?{$_.num -eq $chosen} | select -expand path) -Authentication Kerberos -Credential $UserCredential
                        } else {
                            $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri ($psdir| ?{$_.num -eq $chosen} | select -expand path) -Authentication Kerberos 
                        }
                } catch{
                    if($_ -match 'The username or password is incorrect'){
                        write-warning "UserName or Password incorrect, reenter credentials";                    
                    }else{
                        Write-Error $_
                    } 
                }
            }

        } else {
            foreach ($vdir in $PSDir){
                try{
                    if ($UserCredential){
                        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $vdir.path -Authentication Kerberos -Credential $UserCredential
                    } else {
                        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $vdir.path -Authentication Kerberos 
                    }               
                
                }catch{
                    if($_ -match 'The username or password is incorrect'){
                        write-warning "UserName or Password incorrect, reenter credentials";
                      
                    }else{
                        Write-Error $_
                    } 
                }

                if ($session) {break;}
            }
        }
    } else {
        $path = "http://$server/PowerShell/"
        if ($usercredential){
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $path -Authentication Kerberos -Credential $UserCredential
        } else {
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $path -Authentication Kerberos
        }
    }
    Write-Warning "Importing connection from $($session.ComputerName) for configuration $($session.ConfigurationName) and overwriting local commands."
    Import-pssession $session -AllowClobber
}

#Write-HOst "Stored-Credential"

function backup-ADFSConfiguration ($path =".\"){
    get-command get-adfs* | %{$cmd = $_.name; $file = "$cmd.xml"; Invoke-Expression -command "$cmd | export-clixml $file"} 
}
#Write-HOst "backup-ADFSConfiguration"

function lctc {
(get-history)[-1].commandline | clip
}
#Write-HOst "lctc"

function search-history ($regex,[switch]$ShowAll){

    if ($showall) {
        get-history -count 32767 | ft ID,Commandline -AutoSize | ho $regex
    } else {
        get-history -count 32767 | ?{$_.commandline -match $regex}| ft ID,Commandline -AutoSize | highlight-output $regex
    }

}
#Write-HOst "Search-History"

function ADFSClipFilter ($activityID){
       $filternew = @"
<QueryList>
  <Query Id="0" Path="AD FS/Admin">
    <Select Path="AD FS/Admin">*[System/Correlation/@ActivityID="{$activityID}"]</Select>
  </Query>
</QueryList>
"@ 
$filterNew | clip
$filterNew
}
#Write-HOst "ADFSClipFilter"


function highlight-String($pattern,[switch]$exact,[switch]$casesensitive) {
 <#
.DESCRIPTION
Highlight text in a string according to a regular expression

.PARAMETER pattern
Your regular expression eg. ".+@.+"

.EXAMPLE
get-childitem | out-string -stream | highlight-String "\w+\.doc"
Displays the current directory and highlights all files that have a .doc extension
 #>
    begin {
        #default to case insensitive        
	    if (!$exact -and !$casesensitive){
		    $regex = new-object System.Text.RegularExpressions.Regex ($pattern, @([System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
	    } else {
            $regex = new-object System.Text.RegularExpressions.Regex ($pattern, @([System.Text.RegularExpressions.RegexOptions]::None))
        }
    }
    
    Process {   
        
        #Apply Regex magic
        $a = $regex.matches($_)
        #Does it need higlighting? No, dump it!
        if (!$a) {
            $_;
           
        }else
        {
            #it must be highlighted
            $startindex = 0;
            foreach ($match in $a){ #on each match, dump the text before it, and the highlighted text
                Write-Host $_.substring($startindex, $match.index -$startindex) -nonewline
                Write-host $match.value -backgroundcolor yellow -foregroundcolor black -nonewline
                $startindex = $match.index + $match.length;
            }
            #if there is still some text left,drop it out
            if ($startindex -lt $_.length-1){
                Write-host $_.substring($startindex,$_.length -$startindex)
            } else{
                #otherwise, just newline
                Write-host
            }
        }
    }
} #End Higlight-String
#Write-HOst "Highlight-String"

function highlight-output ($pattern,[switch]$exact,[switch]$casesensitive){
 <#
.DESCRIPTION
Highlight output according to a regular expression

.PARAMETER pattern
Your regular expression eg. ".+@.+"

.EXAMPLE
get-childitem | highlight-output "\w+\.doc"
Displays the current directory and highlights all files that have a .doc extension
 #>
    $input | out-string -stream | highlight-string @PSBoundParameters
}
#Write-HOst "Highlight-Output Alias:HO"

#Create  HO as an alias; Get-childitem | ho "\w+\.doc"
new-alias ho highlight-output 

$Global:O365Connected = ""
function connect-MSOL ($name, [switch]$new)
{
	Import-Module MSOnline
	$O365Cred = Stored-Credential $name -new:$new
	$O365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell -Credential $O365Cred -Authentication Basic -AllowRedirection
	Import-PSSession $O365Session -allowclobber
	Connect-MsolService -Credential $O365Cred
	$Global:O365Connected = $name

}
new-alias cm connect-MSOL 
#Write-HOst "Connect-MSOL Alias:CM"

 function prompt {

	"$((get-date).ToUniversalTime().tostring('u'))`r`n$($Global:O365Connected) $(get-location)>"

}

function quit{
    get-pssession | remove-pssession
    exit
}
#Compare-SideBySide
#Author: Shane Wright
#www.wrish.com
function Compare-SideBySide
<#
.Synopsis 
Compare Objects side by side.
 
.Description
Has the effect of comparing properties of an array of objects side by side. Accomplishes this by Creating an array of each set of properties.


.PARAMETER Properties
Supply a list of properties to select in the comparison, by default, all properties are selected. *Method type properties are never selected.
Can be wild cards *name,Enabled,*address.

.PARAMETER NameProperty
Supply the property that will appear as the header for each column. The first matching property is selected.
By Default Displayname,userprincipalname,samaccountname or any property ending with name (the first found) is used.
Can be wild cards eg *name*

.PARAMETER excludedProperties
Supply a list of properties to exclude from the comparison, by default no properties are excluded.
Can be wild ards eg msexch*

.PARAMETER Differences
Include this switch to only display the differences between objects

.EXAMPLE
get-aduser -filter "samacountname -like John*" -Properties * | Compare-SideBySide -properties DisplayName,GivenName,Enabled
Property                                            John Smythe                                         John Jonahs                                         John Charlies                                       Johnny Brogard                                    
--------                                            -----------                                         -----------                                         -------------                                       ---------------                                    
DisplayName                                         John Smythe                                         John Jonahs                                         John Charlies                                       Johnny Brogard                                    
Enabled                                             False                                               True                                                False                                               False                                              
GivenName                                           John                                                John                                                John                                                Johnny                                             

.Notes
Author: Shane Wright
Website: www.wrish.com
Last Edited: 30th March 2013
Keywords: Comparison, Compare, Side by Side

.LINK
http://www.wrish.com
#>
{
  param (
     $Properties = "*",
     $NameProperty = @("Name","displayName","userprincipalname","samaccountname","*name"),     
     $excludedProperties = $null,
     [switch]$Differences
  )

   Begin {
        #Setup the script
        $First = $true; #Flag that the First column has to be generated
        $CObject = @(); #The array that will contain the results
        $ObjectCounter = 0; #keep track of the object number
        $SelNameProperty = "";        
    }
    
    Process {
        if ($First){
            $First = $false;
            #Figure out which properties are to be included in the comparison
            $AllProperties = get-member -inputobject $_;
            $SelProperties = @();
            foreach ($property in $AllProperties){
                :NotThisProperty foreach ($propertyfilter in $Properties){
                    if ($property.name -like $PropertyFilter -and $property.MemberTYpe -notlike '*Method'  ) {
                        foreach ($ExcludeFilter in $excludedProperties){
                            if ($property.name -like $excludeFilter){break NotThisProperty;} 
                        }
                        $SelProperties += $property.name
                        break;
                    }
                }  #NotThisProperty                           
            } 
            
            #Select the Name property
            :WinningProperty foreach ($option in $NameProperty)
            {
                foreach ($property in $AllProperties){
                    if ($property.name -like $option){
                        $SelNameProperty = $property.name;
                        break WinningProperty;
                    }
                }
            }            
            #Generate All the property objects
            foreach ($property in $selProperties){
                   $thisRow = new-object PSObject -Property @{'Property'=$property}
                   $CObject += $thisRow;
            }
        }    
        #Determine the Naming Property Value
        if ($SelNameProperty) {
            $myNameProperty = $_.$SelNameProperty
        } else
        {
            $myNameProperty = "Object $ObjectCounter"
        }
        $ObjectCounter ++;
        $currentObject = $_
        #Add this Object as a new Property to all the objects
        foreach ($property in $CObject){        
            $thisProperty = $property.Property
            try{
                add-member -inputobject $property -name $myNameProperty -value ($currentObject.$thisProperty) -membertype NoteProperty -ErrorAction "Stop";
            }
            catch{                
                add-member -inputobject $property -name "$myNameProperty [$ObjectCounter]" -value ($currentObject.$thisProperty) -membertype NoteProperty;
            }
        }
          
    }
    
    End{
        #return the transformed object
        if($Differences -and $CObject.length -gt 1 -and (get-member -inputobject $CObject[0] -memberType NoteProperty).length -gt 2){
            $Objs = $CObject[0] | get-member -memberType NoteProperty | ?{$_.name -ne 'Property'} | select -expand Name;            
            $CObject | ?{$row = $_; ($Objs | foreach-object {$row.$_}| select -unique | measure).count -gt 1}            
        } else {
            $CObject    
        }
    }
}


new-alias csbs Compare-SideBySide 
#Write-HOst "Compare-SideBytSide Alias:csbs"


Function Test-Port ($DestinationHosts,$Ports,[switch]$noPing,$pingTimeout="2000",[switch]$ShowDestIP,[Switch]$Continuous,$waitTimeMilliseconds=300,$maxthreads = 100) { 
  
    #ScriptBlock to check the port and return the result
    $Script_CheckPort = {
        $Source = $Args[0];
        $Destination = $args[1];
        $Port = $args[2];
        $PingTimeout = $Args[3]; 
        $ShowIP = $args[4];

        #Generate the result Object
        $result = New-Object psobject -property @{Source=$Source;Dest=$destination;Port=$Port;Result="";Error=$()}

        #If IP is requested add to the result
        if ($ShowIP){
            try {
                $result | add-member -MemberType NoteProperty -Name "Dest IP" -value (([System.Net.Dns]::GetHostAddresses($Destination) | select -expand IPAddressToString) -join ";") -Force
            } catch {
                $result.error += $_;
                $result | add-member -MemberType NoteProperty -Name "Dest IP" -value $Destination -Force
            }
        }

        #if it is a Ping
        if ($Port -eq "PING"){
            try {
                $ping = new-object System.Net.NetworkInformation.Ping
                $result.Result = $ping.send($destination,$PingTimeout).Status
            } catch {
                $result.error += $_;
                $result.Result = "Unresolvable"
            } finally {
                if($ping){$ping.dispose();$ping = $null}
            }
        
        } else {
        #it is a socket
            try{
                $socket = new-object System.Net.Sockets.TcpClient($destination, $port)
                if ($socket -eq $null) {
                    
                } elseif ($socket.connected -eq $true) {
                    $result.result = "Success"
                }
            } catch {
                $result.error += $_
                $thisError = $_
                switch -regex ($_.ToString()) {
                    'actively refused' { $result.result ='Refused'; break;}
                    'No such host is known' {$result.result = 'HostName Error';break;}
                    default {$result.result = 'FAIL'}
                }
            } finally {
                if ($socket.Connected){
                    $socket.close()
                }
                if ($socket){
                    $socket.Dispose()
                }
                $socket = $null
            }
        }
        Write-Output $result

    }
    #Get the list of ports for the query
    if (!$noPing) {$portsToQuery = @('PING');} else {$portsToQuery=@()}

     switch -regex ($ports) {
        '(?i)Domain|DC|AD|Active Directory' {$portsToQuery += @(445,389,88,3268)}
        '(?i)Web' {$portsToQuery += @(80,443)}
        '(?i)http(^s)' {$portsToQuery += 80 }
        '(?i)https' {$portsToQuery += 443 }
        '(?i)smb' {$portsToQuery += 445 }
        '(?i)SCOM|Ops Man|Operations Manager' {$portsToQuery += 5723}
        '(?i)rdp|remote desktop|mstsc' {$portsToQuery += 3389}
        '(?i)remoting|[^t]PS|PowerShell' {$portsToQuery += @(5985,5986)}
        '(?i)eset' {$portsToQuery += @(2222,2221)}
        default {if ($_ -is [int32]){$portsToQuery+=$_}}     
     }
     $PortsToQuery = $POrtsToQuery | Sort-Object -descending | Select-object -unique
     $hostname = hostname
     #run the lookup
     
     $iss = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
     $pool = [Runspacefactory]::CreateRunspacePool(1, $maxthreads, $iss, $host)
     $pool.open()
     $threads = @()
     $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($Script_CheckPort.toString())
     $FirstRun = $True
     try {           
         While ($continuous -or $FirstRun) {
             foreach ($Destination in $DestinationHosts) {
                foreach ($port in $POrtsToQuery) {
                    $powershell = [powershell]::Create().addscript($scriptblock).addargument($hostname).addargument($Destination).AddArgument($port).AddArgument($pingTimeout).AddArgument($ShowDestIP)
                    $powershell.runspacepool=$pool
                    $threads+= @{
                        instance = $powershell
                        handle = $powershell.begininvoke()
                    }            
           
                }
             }
     
             $notdone = $true
             while ($notdone) {
                $notdone = $false
                for ($i=0; $i -lt $threads.count; $i++) {
                    $thread = $threads[$i]
                    if ($thread) {
                        if ($thread.handle.iscompleted) {
                            $thread.instance.endinvoke($thread.handle)
                            $thread.instance.dispose()
                            $threads[$i] = $null
                        }
                        else {
                            $notdone = $true
                        }
                    }
                }
                Start-Sleep -milliseconds 300
            }
            if ($continuous) {
                Start-Sleep -Milliseconds $waitTimeMilliseconds
            } else {
                $firstrun = $False
            }
        }
    } catch {
        throw $_
    } finally {
        $pool.close()  
        $iss = $null
        $threads = $null
        $scriptblock = $null
    }

}

new-alias tp Test-Port 
#Write-HOst "Test-Port Alias:tp"


function get-adsite ($sitename='*',$ldapfilter,$Server,$pageSize=1000)
<#
.DESCRIPTION
Get AD sites from the current domain

.Parameter SiteName
The name or part name of the site for wildcards use *

.Parameter LdapFilter
If you need a fancy filter, put it here - for examaple description=*USA*

.Parameter Server
If you want to look up the sites on a specific server, enter that name here.

.Paramenter PageSize
LDAP Search page size, default 1000

#>
{
    if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    $Root = [ADSI]"LDAP:/$server/RootDSE"  
    
    $AdSearcher = [adsisearcher]"(&(objectclass=site)(name=$sitename)$ldapfilter)"
    $AdSearcher.Searchroot = [ADSI]("LDAP:/$Server/cn=sites,$($Root.configurationNamingContext)")
    $ADSearcher.PageSize = $pageSize   
    foreach ($site in $ADSearcher.Findall()){
        $SiteObject = new-object psobject
        foreach ($property in ($site.properties.get_propertyNames())){
            if (($site.properties.$property | measure).count -le 1){
                $SiteObject | add-member -name $property -value $site.properties.$property[0] -MemberType NoteProperty
            } else {
                $SiteObject | add-member -name $property -value $site.properties.$property -MemberType NoteProperty
            }
        }
        write-output $SiteObject
    }
}
#Write-HOst "get-adsite"



function ForEach-Parallel {
<#
.Description
Process pipeline using multiple threads.
Adapted from http://powertoe.wordpress.com/2012/05/03/foreach-parallel/
.Parameter ScriptBlock
This is the scriptblock to be processed.

.Parameter InputObject
Object or objects from the pipeline

.Parameter MaxThreads
The maximum number of simultaneously executed threads. Higher numbers will achieve higher throughput, but may cause resource contention.

.Parameter Arguments
Arguments to be passed to the scriptblock

.Parameter ImportFunctions
List of functions that should be available to the script block 

#>
                param(
                    [Parameter(Mandatory=$true,position=0)]
                    [System.Management.Automation.ScriptBlock] $ScriptBlock,
                    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
                    [PSObject]$InputObject,
                    [Parameter(Mandatory=$false)]
                    [int]$MaxThreads=100,
                    [Parameter(Mandatory=$false)]$arguments,
                    [Parameter(Mandatory=$false)][string[]]$ImportFunctions,
                    [Parameter(Mandatory=$false)][switch]$objectReturn,
                    [Parameter(Mandatory=$false)][string]$ItemLabel="InputObject",
                    [Parameter(Mandatory=$false)][string]$ResultLabel="Result",
                    [switch]$noProgress,
                    [String]$ActivityName = "Multithreaded Foreach-Parallel",
                    $chunking = 1
                )
                BEGIN {
                    $iss = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
                    $pool = [Runspacefactory]::CreateRunspacePool(1, $maxthreads, $iss, $host)
                    $pool.open()
                    $threads = @()
                     #import declared functions
                     $FunctionSet = ''
                    foreach ($funct in $ImportFunctions){
                        $command = get-command $funct
                        if ($command.definition) {
                           $FunctionSet += 'function ' +$funct +' {' + $Command.definition + "}`r`n"                      
                        } else {
                            Write-Error "Unable to import $funct, no definition available"
                        }
                    }
                    if ($objectReturn){
                        $scriptblock = [scriptblock]::Create("`$OutResult_ = `"`"| Select $ItemLabel,$ResultLabel,Error; `$OutResult_.$ItemLabel = `$_; `$OutResult_.$ResultLabel = try {$($Scriptblock.ToString())} catch{`$OutResult_.Error = `$_};`$OutResult_")
                    }

                    if ($chunking -eq 1) {$scriptblock = [scriptblock]::Create("param(`$_)`r`n" + $functionSet + $Scriptblock.ToString())}
                    else{$scriptblock = [scriptblock]::Create("param(`$_)`r`n" + $functionSet + '$_ | foreach-object {' + $Scriptblock.ToString() + '}')}
                    
                    Write-debug $scriptblock.tostring()                    
                    if ($chunking -gt 1) {
                        $arrayBlock = @()
                        $counter = 0
                        $index = 0                       
                    }               
                }
                PROCESS {
                    if ($chunking -gt 1) {
                        $arrayBlock += $InputObject
                        $counter++
                        if ($counter -eq $chunking){
                            $counter = 0
                            $index++
                            Write-debug "Processing chunk number $index of $chunking objects" 
                             $powershell = [powershell]::Create().addscript($scriptblock).addargument($arrayBlock);

                            #import declared arguments
                            foreach ($Arg in $arguments) {
                                $powershell = $powershell.AddArgument($arg);
                            }                   
                            $powershell.runspacepool=$pool
                            $threads+= @{
                                instance = $powershell
                                handle = $powershell.begininvoke()
                            }
                            if(!$noprogress){write-progress -Activity $ACtivityname -Status "Creating Threads [Threads Created:$($threads.count)]" -PercentComplete -1}
                            $totalThreads = $threads.count
                            $arrayBlock = @()                       
                        }                                               
                    } else {
                        Write-debug "Processing $InputObject"
                        $powershell = [powershell]::Create().addscript($scriptblock).addargument($InputObject);

                        #import declared arguments
                        foreach ($Arg in $arguments) {
                            $powershell = $powershell.AddArgument($arg);
                        }                   
                        $powershell.runspacepool=$pool
                        $threads+= @{
                            instance = $powershell
                            handle = $powershell.begininvoke()
                        }
                        if(!$noprogress){write-progress -Activity $ACtivityname -Status "Creating Threads [Threads Created:$($threads.count)]" -PercentComplete -1}
                        $totalThreads = $threads.count
                    }
                }
                END {
                    if ($chunking -gt 1 -and $arrayBlock) {
                        $index++
                        Write-debug "Processing chunk number $index of $chunking objects" 
                            $powershell = [powershell]::Create().addscript($scriptblock).addargument($arrayBlock);

                        #import declared arguments
                        foreach ($Arg in $arguments) {
                            $powershell = $powershell.AddArgument($arg);
                        }                   
                        $powershell.runspacepool=$pool
                        $threads+= @{
                            instance = $powershell
                            handle = $powershell.begininvoke()
                        }
                        if(!$noprogress){write-progress -Activity $ACtivityname -Status "Creating Threads [Threads Created:$($threads.count)]" -PercentComplete -1}
                        $totalThreads = $threads.count                                                 
                    }
                    $notdone = $true
                    $threadsClosed = 0
                    while ($notdone -and $totalThreads -gt 0) {
                        if(!$noprogress){ write-progress -Activity $ACtivityname  -Status "Running Threads [Completed:$threadsClosed total:$totalThreads]" -PercentComplete ([math]::floor(($threadsClosed/$totalThreads) * 100))}
                        $notdone = $false
                        for ($i=0; $i -lt $threads.count; $i++) {
                            $thread = $threads[$i]
                            if ($thread) {
                                if ($thread.handle.iscompleted) {
                                    $thread.instance.endinvoke($thread.handle)
                                    $thread.instance.dispose()
                                    $threads[$i] = $null
                                    $threadsClosed += 1
                                   if(!$noprogress){ write-progress -Activity $ACtivityname  -Status "Running Threads [Completed:$threadsClosed total:$totalThreads]" -PercentComplete ([math]::floor(($threadsClosed/$totalThreads) * 100))}
                                }
                                else {
                                    $notdone = $true
                                }
                            }
                        }
                        start-sleep -Milliseconds 300
                    }
                }
            }


New-Alias %p ForEach-Parallel
#Write-HOst Foreach-Parallel Alias:%p

function Invoke-SDPropagator 
<#
.Description 
Invoke the SDPropagator on the current domain (users domain) 

.Parameter ShowProgress
Display progress and wait for sdpropagation to complete use -showprogress:$false to not wait for propagation to complete.

.Parameter TimeoutMinutes
The number of minutes to wait for SDPropagation to start

.Parameter Domain
Can be used to target remote domains - Domain Admin access is required, so this may not actually be possible.
#>
{
    [CmdletBinding()]Param([switch]$showProgress=$true,$timeoutMinutes=10,[string]$Domain)
    #https://support.microsoft.com/en-us/help/251343/manually-initializing-the-sd-propagator-thread-to-evaluate-inherited-p
    try {
        if ($domain) {$Domain += '/'}
        $PDC =  ([adsi]([adsi]"LDAP://$(([adsi]"LDAP://$(([adsi]"LDAP://$domain`RootDSE").defaultNamingContext)").fsmoroleowner)").parent ).dnshostname 
        Write-Verbose "PDC Located at $PDC"

        $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$PDC/RootDSE")
        $RootDSE.UsePropertyCache = $false
    
        Write-Verbose "Initiating SD Propogation on $PDC"
        $RootDSE.Put("fixupinheritance", "1")
        $RootDSE.SetInfo() 

        if ($showProgress){
            Write-Verbose "Checking for start of SD Propagator"
            $FailDetect = (get-date).AddMinutes($timeoutMinutes)
            $RuntimeQueue = 0
            $RuntimeMax = 0
            $InvokeDetected = $false            
            
            while (($invokeDetected -eq $false -and  (get-date) -lt $FailDetect) -or ($InvokeDetected -eq $true -and $RuntimeQueue -gt 0)){
                $RuntimeQUeue = (get-counter -counter '\directoryservices(ntds)\ds security descriptor propagator runtime queue' -ComputerName $PDC).countersamples.cookedvalue
                if ($RuntimeQueue -gt $RuntimeMax){
                    $InvokeDetected = $true
                    $RuntimeMax = $RuntimeQueue
                }
                if ($InvokeDetected) {
                    Write-Progress -Activity "Invoke-SDPropagator on $PDC" -Status "Waiting for SDPropagator to finish" -PercentComplete ((($runTimeMax - $RuntimeQueue)/($runtimemax)) * 100)
                } else {
                    Write-Progress -Activity "Invoke-SDPropagator on $PDC" -Status "Waiting for SDPropagator to start" -SecondsRemaining ($FailDetect - (get-date)).totalseconds
                }
                start-sleep -seconds .5
            }
        }
    } catch {
        Write-Error "Unable to complete SD Propogation because $_"
    }
}
     

            
function get-ForestDomainControllers ([switch]$quickly)
{
    if ($quickly) {
        return (New-Object adsisearcher([adsi]"LDAP://$(([adsi]"LDAP://rootdse").configurationNamingContext)","(objectClass=nTDSDSA)")).findall() | %{($_.properties.distinguishedname[0] -replace 'cn=NTDS Settings,','')} | %{[adsi]"LDAP://$_"} | select -expand dnshostname
    } else {
        $mresult = @()
        $AllDomains = ([System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()).domains     
        Foreach ($domain in $alldomains){
            $mresult += get-addomaincontroller -filter * -server $domain.name | select Domain,Name,hostname,site,OperatingSystem,Ipv4Address;
        }
        return $mresult;
    }
}
#Write-HOst Get-forestDomainControllers

function get-adsite ($sitename='*',$ldapfilter,$Server,$pageSize=1000)
<#
.DESCRIPTION
Get AD sites from the current domain

.Parameter SiteName
The name or part name of the site for wildcards use *

.Parameter LdapFilter
If you need a fancy filter, put it here - for examaple description=*USA*

.Parameter Server
If you want to look up the sites on a specific server, enter the server name here.

.Paramenter PageSize
LDAP Search page size, default 1000

#>
{
    if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    $Root = [ADSI]"LDAP:/$server/RootDSE"  
    
    $AdSearcher = [adsisearcher]"(&(objectclass=site)(name=$sitename)$ldapfilter)"
    $AdSearcher.Searchroot = [ADSI]("LDAP:/$Server/cn=sites,$($Root.configurationNamingContext)")
    $ADSearcher.PageSize = $pageSize   
    foreach ($site in $ADSearcher.Findall()){
        $SiteObject = new-object psobject
        foreach ($property in ($site.properties.get_propertyNames())){
            if (($site.properties.$property | measure).count -le 1){
                $SiteObject | add-member -name $property -value $site.properties.$property[0] -MemberType NoteProperty
            } else {
                $SiteObject | add-member -name $property -value $site.properties.$property -MemberType NoteProperty
            }
        }
        write-output $SiteObject
    }
}

#Write-HOst get-adsite

function get-adsitelink ($SiteLinkName='*',$ldapfilter,$Server,$pageSize=1000)
<#
.DESCRIPTION
Get AD SiteLinks from the current domain

.Parameter SiteLinkName
The name or part name of the site for wildcards use *

.Parameter LdapFilter
If you need a fancy filter, put it here - for examaple description=*USA*

.Parameter Server
If you want to look up the Sitelinks on a specific server, enter the server name here.

.Paramenter PageSize
LDAP Search page size, default 1000

#>
{
    if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    $Root = [ADSI]"LDAP:/$server/RootDSE"  
    
    $AdSearcher = [adsisearcher]"(&(objectclass=sitelink)(name=$SiteLinkName)$ldapfilter)"
    $AdSearcher.Searchroot = [ADSI]("LDAP:/$Server/cn=sites,$($Root.configurationNamingContext)")
    $ADSearcher.PageSize = $pageSize   
    foreach ($site in $ADSearcher.Findall()){
        $SiteObject = new-object psobject
        foreach ($property in ($site.properties.get_propertyNames())){
            if (($site.properties.$property | measure).count -le 1){
                $SiteObject | add-member -name $property -value $site.properties.$property[0] -MemberType NoteProperty
            } else {
                $SiteObject | add-member -name $property -value $site.properties.$property -MemberType NoteProperty
            }
        }
        write-output $SiteObject
    }
}

#Write-HOst get-adsitelink

function get-adsubnet ($subnetName='*',$ldapfilter,$Server,$pageSize=1000)
<#
.DESCRIPTION
Get AD Subnets from the current domain

.Parameter SubnetName
The name or part name of the site for wildcards use *

.Parameter LdapFilter
If you need a fancy filter, put it here - for examaple description=*USA*

.Parameter Server
If you want to look up the Sitelinks on a specific server, enter the server name here.

.Paramenter PageSize
LDAP Search page size, default 1000

#>
{
    if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    $Root = [ADSI]"LDAP:/$server/RootDSE"      
    $AdSearcher = [adsisearcher]"(&(objectclass=subnet)(name=$subnetName)$ldapfilter)"
    $AdSearcher.Searchroot = [ADSI]("LDAP:/$Server/cn=subnets,cn=sites,$($Root.configurationNamingContext)")
    $ADSearcher.PageSize = $pageSize   
    foreach ($site in $ADSearcher.Findall()){
        $SubnetObject = new-object psobject
        foreach ($property in ($site.properties.get_propertyNames())){
            if (($site.properties.$property | measure).count -le 1){
                $SubnetObject | add-member -name $property -value $site.properties.$property[0] -MemberType NoteProperty
            } else {
                $SubnetObject | add-member -name $property -value $site.properties.$property -MemberType NoteProperty
            }
        }
        try {
            $ErrorActionPreference = "Stop"
            $sitename = $null
            if ($SubnetObject.siteObject){$SiteName = ([ADSI]("LDAP:/$Server/$($SubnetObject.siteObject)")).cn[0]}
        } catch {
            Write-Warning "$($subnetObject.name) is not assigned to a valid site object"
        }
        $subnetObject | add-member -name Site -value $sitename  -MemberType NoteProperty -PassThru        
    }
}


function join-objects ($left, $right, $index,$leftExclude=@(),$rightExclude=@()) {
    $leftProcessed = $left | sort $index
    $rightProcessed = $right | sort $index
    $leftfields = $left | get-member -MemberType NoteProperty | select -expand Name | ?{$_ -notmatch $index -and $leftExclude -notcontains $_}
    $rightfields = $right | get-member -MemberType NoteProperty | select -expand Name | ?{$_ -notmatch $index -and $rightExclude -notcontains $_}
    $results = @();    
    $rInd = 0;
    foreach ($item in $leftProcessed) {
        foreach ($field in $rightfields) {
            $item | add-member -MemberType NoteProperty -Name $field -Value $null -force
        }            
        while ($rind -lt $rightProcessed.length -and $item.$index -lt $rightProcessed[$rInd].$index){
            $rInd ++;
        }
        if ($rind -lt $rightProcessed.length) {
            if ($item.$index -eq $rightProcessed[$rInd].$index)
            {
                foreach ($field in $rightfields) {
                    $item.$field =  $rightProcessed[$rInd].$field
                } 
                $rind ++;
            } else {
                $NewEntry = $rightProcessed[$rind]
                foreach ($field in $leftfields) {
                    $NewEntry | add-member -MemberType NoteProperty -Name $field -Value $null  -force
                }
                $results += $newEntry
                $rind ++;
            }
        }
        $results +=$item
    }
write-output $results
}
#Write-HOst get-adsubnet

function get-ADConfServer ($ServerName='*',$DN,$server,$LDAPFilter,$PageSize)
{
    if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    $Root = [ADSI]"LDAP:/$server/RootDSE"      
    $AdSearcher = [adsisearcher]"(&(objectclass=server)(cn=$ServerName)$ldapfilter)"
    $AdSearcher.Searchroot = [ADSI]("LDAP:/$Server/cn=sites,$($Root.configurationNamingContext)")
    if ($DN) {
        $DN = $DN -join ','
        $AdSearcher.Searchroot = [ADSI]("LDAP:/$Server/$DN")
        }
    $ADSearcher.PageSize = $pageSize   
    foreach ($SC in $ADSearcher.Findall()){
        $SCObject = new-object psobject
        foreach ($property in ($SC.properties.get_propertyNames())){
            if (($SC.properties.$property | measure).count -le 1){
                $SCObject | add-member -name $property -value $SC.properties.$property[0] -MemberType NoteProperty
            } else {
                $SCObject | add-member -name $property -value $SC.properties.$property -MemberType NoteProperty
            }
        }
        $SCObject | add-member -name NTDSSettings -value "CN=NTDS Settings,$($SCObject.distinguishedname)" -MemberType NoteProperty
        $SCObject | add-member -name ADSite -value ($scobject.distinguishedname -split '\,CN=')[2] -MemberType NoteProperty
        write-output $SCObject
    }
}
#Write-HOst get-adconfServer

function get-adConnection ($fromServer,$toServer,$anyServer,$server,$site,$ldapfilter,$pageSize=1000){
<#
.DESCRIPTION
Get AD Connection Objects

.Parameter fromServer
Retrieve connection objects that replicate from this server

.Parameter toServer
Retrieve connection objects that replicate to this server

.Parameter anyServer
Retrieve connection objects that replicate to or from this server

.Paramenter Site 
Retrieve connection objects in this site only

.Parameter Server
If you want to look up the Connection objects on a specific server, enter the server name here.

.Paramenter PageSize
LDAP Search page size, default 1000
#>
  if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    #If Site is defined calculate the search root
    if ($site) {
        $ADSite = get-adsite $site;
        if (!$ADSite -or ($ADSITE | measure).count -gt 1) {
            Write-Error "Site $site not found or matches more than one site";
            return;
        }
        $searchRoot = [ADSI]("LDAP:/$Server/$($adSite.distinguishedName)")
    } elseif ($toServer){
        $toServer = get-adConfServer $toServer
        if ($toServer) {
            $searchroot = $toServer | %{[ADSI]("LDAP:/$Server/$($_.NTDSsettings)")}
        }   
    } else {
        $Root = [ADSI]"LDAP:/$server/RootDSE"
        $searchroot = [ADSI]("LDAP:/$Server/cn=sites,$($Root.configurationNamingContext)")
    }

    #generate a filter for the fromserver values
    if ($fromServer){
        $fromServer = get-ADConfServer $fromServer
        if ($fromServer) {
            $ldapfilterFrom = '(fromserver=' + (($fromServer | select -expand NTDSSettings) -join ')(fromserver=') + ')'
            if (($fromServer | measure).count -gt 1){
                $ldapfilterFrom = '(|' + $ldapfitlerfrom + ')'
            }
        }        
    }   
    
    $searchroot | %{
        $AdSearcher = [adsisearcher]"(&(objectclass=nTDSConnection)$ldapfilterFrom)"
        $AdSearcher.Searchroot = $_
        $ADSearcher.PageSize = $pageSize   
        foreach ($site in $ADSearcher.Findall()){
            $SubnetObject = new-object psobject
            foreach ($property in ($site.properties.get_propertyNames())){
                if (($site.properties.$property | measure).count -le 1){
                    $SubnetObject | add-member -name $property -value $site.properties.$property[0] -MemberType NoteProperty
                } else {
                    $SubnetObject | add-member -name $property -value $site.properties.$property -MemberType NoteProperty
                }
            }
            $subnetObject | add-member -name ToServer -MemberType NoteProperty -value (($subnetObject.distinguishedname -split '\,')[2..100] -join ',') 
            $subnetObject.fromServer = (($subnetObject.fromServer -split '\,')[1..100] -join ',') 
            write-output $SubnetObject
        }
    }
}

#Write-HOst get-adConnection

function Check-ForestReplications {
    get-ForestDomainControllers | ForEach-Parallel {                
        $replresult = repadmin /showrepl $_.hostname /csv
        write-output (new-object psobject -Property @{server=$_.hostname;ReplResults=$replResult})
    }
}



#Write-HOst Check-ForestReplications

function get-adDevice ($DisplayName='*',$RegisteredOwner,$RegisteredUser,$ldapfilter,$Server,$pageSize=1000)
<#
.DESCRIPTION
Get AD sites from the current domain

.Parameter DeviceName
The displayName of the device

.Parameter LdapFilter
Accepts filters in LDAP form - for examaple description=*USA*

.Parameter RegisteredUser
Search for devices with a specific registered user

.Parameter RegisteredOwner
Search for devices with a specific registered owner

.Parameter Server
Direct your query to a specific server

.Paramenter PageSize
LDAP Search page size, default 1000

#>
{
    if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    $Root = [ADSI]"LDAP:/$server/RootDSE"  
    
    #Users are stored against the MSDS-Device object using the SID, convert the user to a SID and add to the ldap filter
    if ($RegisteredOwner) {
        try {
            $userSid = (New-Object System.Security.Principal.NTAccount ($RegisteredOwner)).Translate([System.Security.Principal.SecurityIdentifier]).value
            $ldapfilter += "(msDS-RegisteredOwner=$usersid)"
        }
        catch {
                Write-Error "Failed to locate principal $RegisteredOwner, confirm that the object exists in the directory."
        }
    }
    
    if ($RegisteredUser) {
        try {
            $userSid = (New-Object System.Security.Principal.NTAccount ($RegisteredUser)).Translate([System.Security.Principal.SecurityIdentifier]).value
            $ldapfilter += "(msDS-RegisteredUser=$usersid)"
        }
        catch {
                Write-Error "Failed to locate principal $RegisteredUser, confirm that the object exists in the directory."
        }
    }
    
    #Connect to the Domain and setup the searcher
    $DeviceContainer = (get-ADDeviceContainer).distinguishedname    
    $AdSearcher = [adsisearcher]"(&(objectclass=MSDS-Device)(displayname=$displayname)$ldapfilter)"
    $AdSearcher.Searchroot = [ADSI]("LDAP:/$Server/$DeviceContainer")
    $ADSearcher.PageSize = $pageSize   
    
    #perform the search and process the objects
    foreach ($Device in $ADSearcher.Findall()){
        $DeviceObject = new-object psobject
        foreach ($property in ($Device.properties.get_propertyNames())){
            $PropertyValue = $null           
            switch -regex ($property) {
                    'msds-registered(owner|users)'{
                            #SID Properties
                           $UserList = @()
                           #Registered owners/users are stored as a char representation of the SID value
                           foreach ($ByteSid in $Device.properties.$property){
                                $stringSid = [System.Text.Encoding]::ASCII.getstring($ByteSid)  
                                $SIDValue = New-Object System.Security.Principal.SecurityIdentifier($stringSid)                                 
                                try{
                                    $StringRep = $SIDValue.Translate([System.Security.Principal.NTAccount])                                   
                                }
                                catch{
                                    $StringRep = $SIDValue.tostring()
                                }
                                $UserList += $stringRep                                                               
                            }
                            if ($userlist.count -eq 1) {$PropertyValue = $userlist[0]} else {$PropertyValue = $userlist}

                    }                    
                    'objectguid|msds-(deviceid|cloudAnchor)'{
                            #GUID Properties 
                            $ValueList = @()
                            foreach ($Value in $Device.properties.$property){  
                                $ValueList += [guid]$value
                               }
                               if ($ValueList.count -eq 1) {$PropertyValue = $ValueList[0]} else {$PropertyValue = $ValueList}
                    }
                    default{
                        #remove ugly arrays
                        if (($Device.properties.$property | measure).count -le 1){$PropertyValue = $Device.properties.$property[0]} else {$PropertyValue = $Device.properties.$property}
                    }
            }
           
            $DeviceObject | add-member -name $property -value $PropertyValue -MemberType NoteProperty
        }
         
        write-output $DeviceObject
    }
}
#Write-HOst get-adDevice

#locate the AD Device Container within the domain
function get-ADDeviceContainer ($Server)
{
    if ($server){ $server = "/$Server"}      
    if ($ldapfilter){
        $ldapfilter = "($ldapfilter)"
    }

    $Root = [ADSI]"LDAP:/$server/RootDSE"  
      
    
    $AdSearcher = [adsisearcher]"(&(objectclass=MSDS-DeviceContainer)(name=RegisteredDevices))"
    $AdSearcher.Searchroot = [ADSI]("GC:/$Server/$($Root.rootdomainnamingcontext)")  
    foreach ($DeviceContainer in $ADSearcher.Findall()){
        $DeviceContainerObject = new-object psobject
        foreach ($property in ($DeviceContainer.properties.get_propertyNames())){
            if (($DeviceContainer.properties.$property | measure).count -le 1){
                $DeviceContainerObject | add-member -name $property -value $DeviceContainer.properties.$property[0] -MemberType NoteProperty
            } else {
                $DeviceContainerObject | add-member -name $property -value $DeviceContainer.properties.$property -MemberType NoteProperty
            }
        }
        write-output $DeviceContainerObject
    }
}
#Write-HOst get-ADDeviceContainer
Function CleanupUserProfiles
{
  [CmdletBinding(
     SupportsShouldProcess=$true,
    ConfirmImpact="High"
  )]param ($computerName= '.',$AgeLimit='60', $Exclude)

  $dateLimit = (get-date).adddays(-1 * $agelimit)
  $userprofiles = Get-WmiObject -Class Win32_UserProfile -ComputerName .
  $exclusionlist = @('S-1-5-19','S-1-5-18','S-1-5-20','-500$') + $Exclude | where-object {$_}
  foreach ($profile in $userprofiles) {
    $dateLastUsed = [datetime]::ParseExact(($profile.lastusetime -replace '\..+$',''),'yyyyMMddHHmmss',$null )
    if ( $dateLastused -ge $dateLimit){
        write-verbose "Skipping $($profile.sid) because it was last used $dateLastUsed"
        continue;    
    }
    $MatchesExclusion = $false
    foreach ($comparison in $exclusionlist){
        if ($profile.sid -match $comparison -or $profile.localpath -match $comparison)
        {
            $MatchesExclusion = $true
            write-verbose "Skipping $($profile.sid) because it matches exclusion '$comparison'"
            break;
        }
    }
    if ($MatchesExclusion) {continue;}
    $activity = "Remove profile for user $($profile.SID) from computer $Computername with local path $($profile.localpath), last used $dateLastUsed"
    if ($pscmdlet.ShouldProcess($activity)) {
        Write-Verbose "Attempting to $activity"
        $profile.Delete()       
    }
  }
}
#Write-HOst cleanupuserprofiles

function Open-profile { 
    if (! (Test-Path $profile.CurrentUserAllHosts)){
        md $profile.CurrentUserAllHosts
        rd $profile.CurrentUserAllHosts
    }

    notepad $profile.CurrentUserAllHosts
    }
#Write-HOst Open-profile 


function Listen-Port ($port=80){
<#
.DESCRIPTION
 Function to use .Net to listen on a given port, outputs connections to the screen

.PARAMETER Port
The TCP port that the listener should attach to

.EXAMPLE
PS C:\> listen-port 443
Listening on port 443, press CTRL+C to cancel

DateTime                                      AddressFamily Address                                                Port
--------                                      ------------- -------                                                ----
3/1/2016 4:36:43 AM                            InterNetwork 192.168.20.179                                        62286
Listener Closed Safely

.INFO
Created by Shane Wright. Neossian@gmail.com

#>
    $endpoint = new-object System.Net.IPEndPoint ([system.net.ipaddress]::any, $port)    
    $listener = new-object System.Net.Sockets.TcpListener $endpoint
    $listener.server.ReceiveTimeout = 3000
    $listener.start()    
    try {
    Write-Host "Listening on port $port, press CTRL+C to cancel"
    While ($true){
        if (!$listener.Pending())
        {
            Start-Sleep -Seconds 1; 
            continue; 
        }
        $client = $listener.AcceptTcpClient()
        $client.client.RemoteEndPoint | Add-Member -NotePropertyName DateTime -NotePropertyValue (get-date) -PassThru
        $client.close()
        }
    }
    catch {
        Write-Error $_          
    }
    finally{
            $listener.stop()
            Write-host "Listener Closed Safely"
    }

}
#Write-HOst Listen-Port

function Check-ADFSFederationForAllDomains {
    
    get-msoldomain | ?{$_.authentication -eq "Federated" -and !$_.rootDomain } | %{
        Write-host Processing $_.Name
        $SETUP = Get-MsolFederationProperty -DomainName $_.Name
        if ($setup[0].TokenSigningCertificate -eq $setup[1].TokenSigningCertificate -and $setup[0].NextTokenSigningCertificate -eq $setup[1].NextTokenSigningCertificate){
            Write-host $_.Name "Token Signing and Next Token Signing Certificates Match" -ForegroundColor Green      
         } else {
            Write-host $_.Name "Token Signing and/or Next Token Signing Certificates DO NOT Match" -ForegroundColor REd            
            $Setup | ft Source,@{l='TokenSigningCertificate';e={$_.TokenSigningCertificate.thumbprint}},@{l='NextTokenSigningCertificate';e={$_.NextTokenSigningCertificate.thumbprint}} -auto            
         }
      } 
}
#Write-HOst 'Check-ADFSFederationForAllDomains'

Function Update-ADFSFederationForAllDomains ($supportMultipleDomains){
    
    get-msoldomain | ?{$_.authentication -eq "Federated" -and !$_.rootDomain } | %{
        Write-host Processing $_.Name
        Update-MsolFederatedDomain -DomainName $_.Name -SupportMultipleDomain:$supportMultipleDomains
       
      } 
}
#Write-HOst 'Update-ADFSFederationForAllDomains' 
Function get-HTTPSSlcertBinding {
    [cmdletbinding()]Param()
    write-verbose "netsh http show sslcert"
    $BindingsAsText = & netsh http show sslcert
    $bindings = @()
    $thisbinding = $null
    switch -Regex ($BindingsAsText) {
        '--------------------|SSL'{}
        '^$' {if ($thisbinding){$bindings+=$thisbinding;} $thisBinding = New-Object psobject -Property @{};}
        '^(?<Name>[\w\s]+:?[\w]+)\s+:\s(?<Value>.*)$|^(?<Name>Hostname:port\s+):\s(?<Value>.*)$' {
            $thisBinding | Add-Member -MemberType NoteProperty -Name $matches.name.trim() -Value $matches.value.trim() -Force            
        }
        '^(?<Name>[\w\s]+:[\w]+)\s+:\s(?<Value>.*)$' {
            $thisBinding | Add-Member -MemberType NoteProperty -Name "Name" -Value $matches.value.trim() -Force            
        }
    }
    $bindings | ?{$_.name}
}
#Write-HOst 'get-HTTPSSlcertBinding'

Function update-HTTPSSlcertBinding {
    
     [cmdletbinding()]Param($name,$RevocationFreshnessTime,$DSMapperUsage,$CtlIdentifier,$CertificateStoreName,$ApplicationID,$VerifyRevocationUsingCachedClientCertificateOnly,$NegotiateClientCertificate,$URLRetrievalTimeout,$CtlStoreName,$CertificateHash,$UsageCheck,$VerifyClientCertificateRevocation)
    $bindingToUpdate = get-HTTPSSlcertBinding | ?{$_.name -eq $Name}
    if (!$bindingToUpdate){
        throw "No binding named '$name' could be found on the local machine"     
        return;
    }
    $bindingToUpdate | fl *    
    $nameToTag = @{
    'Certificate Hash'='certhash'   ;
    'Application ID'='appid' ;                
    'Certificate Store Name'='certstorename' ;        
    'Verify Client Certificate Revocation'='verifyclientcertrevocation'  ;
    'Verify Revocation Using Cached Client Certificate Only'='verifyrevocationwithcachedclientcertonly' ;
     'Usage Check'='usagecheck';
    'Revocation Freshness Time'= 'revocationfreshnesstime';
   'URL Retrieval Timeout'=  'urlretrievaltimeout';
    'Ctl Identifier'='sslctlidentifier' ;
    'Ctl Store Name'='sslctlstorename' ;
    'DS Mapper Usage'='dsmapperusage' ;
    'Negotiate Client Certificate'='clientcertnegotiation'
    }
    $ParamToName = @{}
    $nametoTag.keys | %{
        $ParamToName.add(($_ -replace ' ',''),$_)
    }
   
    $valueTranslater = @{
    'Enabled'='enable';
    'Disabled'='disable'
    }

    $nametag = $bindingToUpdate | Get-Member -MemberType NoteProperty | ?{$_.name -match ':'} |%{$_.name -replace ':',''}
    
    #update the object values to the entry that will be recreated
    foreach ($argument in $PSBoundParameters.GetEnumerator()){
        $($ParamToName.$($argument.key))
        if ($($ParamToName.$($argument.key))){
            $bindingToUpdate.$($ParamToName.$($argument.key)) = $argument.value
        }
    }
        
    #delete the existing binding
    write-verbose "netsh http delete sslcert $nametag=$name"
    $DeleteResult = & netsh http delete sslcert $nametag=$name
    $DeleteREsult = $DeleteResult -join ''
    if ($DeleteResult -notmatch 'SSL Certificate successfully deleted'){
        throw "Unable to update '$name'; failed to delete the binding, the error was $DeleteResult"
        return $DeleteResult
    }

    #Create the new Binding
    $bindingCreatingString = "netsh http add sslcert --% $nametag=$name"

    $bindingToUpdate | gm | select -expand Name | %{        
        if ($nameToTag.ContainsKey($_) -and $bindingToUpdate.$_ -ne "(null)" -and  $bindingToUpdate.$_ -ne "0"){
            $tag = $nameToTag[$_]
            $value = if ($valueTranslater.ContainsKey($bindingToUpdate.$_)){$valueTranslater[$bindingToUpdate.$_]} else {$bindingToUpdate.$_}
            $bindingCreatingString += " $tag=$value"
        }
    }
    Write-Verbose $bindingCreatingString
    $CreateResult = Invoke-Expression $bindingCreatingString
    $CreateResult = $Createresult -join ''
    
    if ($createResult -notmatch 'SSL Certificate successfully added'){
        throw "Unable to update '$name'; failed to create the binding, the error was $createResult."
    }
    get-HTTPSSlcertBinding | ?{$_.name -eq $Name}
}

#Write-HOst 'update-HTTPSSlcertBinding'

function Connect-Exchange ($Server,[pscredential]$UserCredential,[switch]$list,$version,$site)
{
    if ($server -eq $null){        
        $search = new-object adsisearcher -ArgumentList ([adsi]"LDAP://$(([adsi]"LDAP://rootdse").configurationNamingContext)"), "(&(objectclass=msExchPowerShellVirtualDirectory)(msexchinternalhostname=*))",@("msExchVersion","msExchInternalHostName","distinguishedname")
        $num=0;
        $PSDir =  $search.findall() | sort -descending {$_.properties.msexchversion[0]}  |%{
            
            $vdir = new-object psobject -Property @{num=$null;path=$_.properties.msexchinternalhostname[0];server=$null;Site=$null;version=$null}
            if ($list -or $version -or $site){
                $ServerPath = ($_.properties.distinguishedname[0] -split ",")[3..100] -join ","
                $Serverobj = [adsi]"LDAP://$serverPath"                
                $vdir.version = $serverObj.serialnumber[0]
                $vdir.server = $serverobj.name[0]
                $vdir.Site = $serverobj.msExchServerSite[0] -replace '^CN=|,.*$',''
            }
            $vdir
        }
        $session = $null
        if ($list -or $version -or $site){
            while (!$session)
            { 
                $num = 0
                $PSDir | ?{$list -or ($version -and $_.version -match $version) -or ($site -and $_.site -match $site)} | %{$_.num = $num;$num++; $_} | select Num,Server,Version,Site | ft -AutoSize
                $chosen = read-host "Ctrl+C to cancel or enter a number 0 to $($num -1) to select a server"
                if ($usercredential){
                    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri ($psdir| ?{$_.num -eq $chosen} | select -expand path) -Authentication Kerberos -Credential $UserCredential
                } else{
                    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri ($psdir| ?{$_.num -eq $chosen} | select -expand path) -Authentication Kerberos
                }
            }

        } else {
            foreach ($vdir in $PSDir){
                if ($usercredential) {
                    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $vdir.path -Authentication Kerberos -Credential $UserCredential
                } else {
                    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $vdir.path -Authentication Kerberos
                }

                if ($session) {break;}
            }
        }
    } else {
        $path = "http://$server/PowerShell/"
        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $path -Authentication Kerberos -Credential $UserCredential
    }
    Write-Warning "Importing connection from $($session.ComputerName) for configuration $($session.ConfigurationName) and overwriting local commands."
    Import-pssession $session -AllowClobber
}

New-Alias ce connect-exchange

function get-ImmutableIDfromADObject
{
    [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]$ADObject) 
   process{ 
        if (!$ADObject.objectguid){$ADObject = get-adobject $AdObject -properties objectGuid -server "$((get-addomaincontroller -discover -service GlobalCatalog).hostname):3268"}
        [system.convert]::ToBase64String($ADObject.objectguid.tobytearray())
    }
}

function get-ADObjectFromImmutableID{
      [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$ImmutableID)
   process { get-adobject  ([guid]([system.convert]::FromBase64String($ImmutableID)))}
}

#Write-HOst 'get-ImmutableIDfromADObject'
#Write-HOst 'get-ADObjectFromImmutableID'

function CreateArrayFromPastedText ($returnvalue = "")
{
    $result = @()
    while ($true) {
        $value = read-host    
        if ($value -eq $returnvalue){
            return $result
        } else {
            $result += $value
        }
    }
}

#Write-HOst 'CreateArrayFromPastedText'


function EnumerateMemberOf($Object, $ResultSoFar=@())
{     
    if ($object.memberof){
        $Results =  @();        
        foreach ($group in $Object.memberof){
            #prevent nesting loops trapping by checking to make sure the group hasn't been searched already
            if ($ResultSoFar -notcontains $Group) {
                $TempGroup = [ADSI]"LDAP://$Group" ;
                $ResultSoFar += $Group.ToString();
                $Results += EnumerateMemberOf $TempGroup $ResultSoFar ;
                $Results += $Group;
            }            
         }
        return $Results
    } 
}

function get-ADNestedMembership
<#
    .Description 
    Retrieve a list of all user group memberships including nested memberships of the primary group.

    .Parameter Identity
    Accept any identity such as a DN "CN=tom,ou=Sales,DC=contoso,dc=com" or samaccountname for the current domain Tom.Smith or an AD Object
#>
{  
    [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
           $Identity) 
    PROCESS     {
        foreach ($userIdentity in $identity) {
            $ADuser = get-adobject $userIdentity -Properties memberof,distinguishedname,primaryGroup
            write-output (new-object psobject -property @{distinguishedname=$aduser.distinguishedname;'NestedMemberOf'=(@(enumerateMemberof $ADuser)+(enumerateMemberof (get-adgroup $AdUser.primaryGroup -properties memberof)))})
        }
    }
}
#Write-HOst get-adNestedMembership

function Retrieve-ServerCertFromSocket ($hostname, $port=443, $SNIHeader, [switch]$FailWithoutTrust)
<#
    .Description
    Connect to a remote server using an SSL connection and retrieve the certificate.

    .Parameter Hostname
    The hostname or IP of the server you wish to retrieve the certificate from. Note that this name 
    will be passed in the SNI authentication header if SNIHeader is null.

    .Paremeter Port 
    The port you want to connect to, default is 443.

    .Paremeter SNIHeader
    This value will be passed to the server in the SNI authentication, useful for checking fall back
    certificates and certificates listening on different endpoints.

    .Parameter FailWithoutTrust
    Enabling this switch will cause your connection to fail if you connect to a server where the certificate
    is not trusted, because it doesn't chain or is expired. Instead of getting a certificate you will get a 
    catchable exception.

    .Example Retrieve-ServerCertFromSocket www.wrish.com 443 | Export-Certificate -FilePath C:\temp\test.cer ; start c:\temp\test.cer
    Export the certificate from a server to a file, and then open that file to view the certificate being used

    .Example Retrieve-ServerCertFromSocket www.wrish.com 443 | fl subject,*not*,Thumb*,ser*
    Retrieve a certificate and display the mail useful values to the screen.

#>
{
    if (!$SNIHeader) {
        $SNIHeader = $hostname
    }
    
    $cert = $null
    try {
        $tcpclient = new-object System.Net.Sockets.tcpclient
        $tcpclient.Connect($hostname,$port)

        #Authenticate with SSL
        if (!$FailWithoutTrust) {
            $sslstream = new-object System.Net.Security.SslStream -ArgumentList $tcpclient.GetStream(),$false, {$true}
        } else {
            $sslstream = new-object System.Net.Security.SslStream -ArgumentList $tcpclient.GetStream(),$false
        }

        $sslstream.AuthenticateAsClient($SNIHeader)
        $cert =  [System.Security.Cryptography.X509Certificates.X509Certificate2]($sslstream.remotecertificate)

     } catch {
        throw "Failed to retrieve remote certificate from $hostname`:$port because $_"
     } finally {
        #cleanup
        if ($sslStream) {$sslstream.close()}
        if ($tcpclient) {$tcpclient.close()}        
     }    
    return $cert
}

function EnumerateMemberOf($Object, $ResultSoFar=@())
{ 
#Helper function to walk $object's memberof attribute and list out all group memberships
#this function is not intended to be called directly, use get-adnestedMembership or get-adnestedmembershipwithparent    
    if ($object.memberof){
        $Results =  @();        
        foreach ($group in $Object.memberof){
            #prevent nesting loops trapping by checking to make sure the group hasn't been searched already
            if ($ResultSoFar -notcontains $Group) {
                #Bind directly to the group with ADSI - this will automatically follow referrals and work with 
                #multi domain forests
                $TempGroup = [ADSI]"LDAP://$Group" ;
                $ResultSoFar += $Group.ToString();
                #Enumerate the next level of memberof
                $Results += EnumerateMemberOf $TempGroup $ResultSoFar ;
                $Results += $Group;
            }            
         }
        return $Results
    } 
}

function get-ADNestedMembership
<#
    .Description 
    Retrieve a list of all user group memberships including nested memberships of the primary group.

    .Parameter User
    Accept any identity such as a DN "CN=tom,ou=Sales,DC=contoso,dc=com" or samaccountname for the current domain Tom.Smith or an AD Object
#>
{  
    [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
           $Identity) 
    PROCESS     {
        foreach ($userIdentity in $identity) {
            $ADuser = get-aduser $Identity -Properties memberof,distinguishedname,primaryGroup
            write-output @{distinguishedname=$aduser.distinguishedname;'NestedMemberOf'=(@(enumerateMemberof $ADuser)+(enumerateMemberof (get-adgroup $AdUser.primaryGroup -properties memberof)))}
        }
    }
}


function Get-IPAddressNetwork ($ip,$subnet=23){
    $bitmask = 0
    if (!((1..32) -contains $subnet)){
        
        #Assume subnet in 255.255.255.0 format
        switch ($subnet -split '\.'){
           255{$bitmask+=8};254{$bitmask+=7};252{$bitmask+=6};248{$bitmask+=5};240{$bitmask+=4};224{$bitmask+=3};64{$bitmask+=1};0{}
           default{write-error "Invalid Subnet definition $Subnet is not in the form of a bitmask (eg 24) or a subnet (eg 255.255.0.0)";return;}
        }
    } else {
        $bitmask = $subnet
    }
    Write-verbose "Using bitmask of $bitmask for ip of $IP to calculate subnet"
    #determine what subnet an IP belongs to given a bitmask eg 16,24
    $networkMask = [convert]::tostring(4294967295 -bxor ([math]::pow(2,(32 - $bitmask)) -1),2)
    $count = 0
    ($ip -split "\." | foreach-object {
        $_ -band [convert]::toInt32($networkmask.tostring().substring($count,8),2)               
        $count += 8;
    }) -join "."
}

function Get-HostSite {
[CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][Alias("IpAddress","Host","Address")]$ComputerName)

    if ($computername -match '^(\d{1,3}\.){3}\d{1,3}$'){        
        $IPAddresses = @($ComputerName)
    } else {
        $IPAddresses = [SYSTEM.net.dns]::GetHostAddresses($ComputerName) | ?{$_.addressfamily -eq 'InterNetwork'} | select -expand IPAddressToString
    }
    foreach ($IP in $IPAddresses){
        $site = nltest /DSADDRESSTOSITE:$ip /dsgetsite 2>$null
        Write-Verbose ($site -join "`n`r")
        switch -regex ($site){
            '(?<Ip>(?:\d{1,3}\.){3}\d{1,3})\s+(?<SiteName>[^ ]+)\s+(?<SiteSubnet>(?:\d{1,3}\.){3}\d{1,3}/\d+)'{new-object psobject -Property ($matches)}
        }
    }
}


new-alias Get-IPSite Get-HostSite

function Expand-Object {
 [cmdletbinding()] Param ([parameter(ValueFromPipeline)][psobject[]]$InputObject,
   [string[]]$ExpansionPath, $memberTypes = @("Property","NoteProperty"),[switch]$preserveAllData )
     Process{   
        foreach ($ThisObj in $inputobject){
            $proplist = $thisObj | gm |?{$memberTypes -contains $_.memberType} | select -expand Name
            if ($ExpansionPath.length -eq 0){                
                $thisObj | select $proplist
            } else {
                $AttrToExpand = $ExpansionPath[0]
                if ($ThisObj.$AttrToExpand){                
                    $results = $ThisObj.$attrToexpand | Expand-Object -ExpansionPath $ExpansionPath[1..100] -memberTypes $memberTypes -preserveAllData:$preserveAllData
                    if ($preserveAllData){                        
                       $resultProps = $results | gm |?{$memberTypes -contains $_.memberType} | select -expand Name
                       $newProps = @()
                       $returnproperties = $resultProps | %{$newProps += @{l="$attrToExpand$_";e=[scriptblock]::create("`$_.$_")}}
                       $results = $results  | select $newProps                         
                        
                    }
                    foreach ($prop in ($proplist |?{$_ -ne $attrToExpand})){
                        $results | Add-Member -NotePropertyName $prop -NotePropertyValue $ThisObj.$prop -force
                    }
                    $results
                } else {
                    $ThisObj | select (([array]$proplist + $AttrToExpand) | sort -Unique)
                }
            }
        }
    }
}

function get-ADNestedMembershipWithParent
{   
    [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]$Identity) 
    Process{ 
        foreach ($user in $Identity){
            $ADuser = get-aduser $user -Properties memberof,distinguishedname,primaryGroup
            foreach ($parentGroup in @(($ADuser.memberof) + $aduser.PrimaryGroup)){
                $group = get-adgroup $parentGroup -properties memberof,distinguishedname ;
                $parentResult = new-object psobject -Property @{User=($ADuser.distinguishedname);parent=($group.distinguishedname);groups=$null}        
                write-output $parentResult
                $nestedGroups= (enumerateMemberof $Group) | ?{$_}
                    foreach ($nestedgroup in $nestedGroups){
                    write-output (new-object psobject -Property @{User=($ADuser.distinguishedname);parent=($group.distinguishedname);groups=$nestedgroup} )
                }
            }
        }
    }
}

function get-LdapTokenGroups {
 [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]$ObjectDN) 
<#
    .Description 
    Use tokengroups attribute to retrieve a list of group memberships including nested groups in the current domain
#>
    Process {
        foreach ($DN in $objectDN) {
            $ADObject = get-adobject -SearchBase $objectDN -SearchScope Base -Properties TokenGroups  -filter *  
            $ResultObject = new-object psobject -Property @{User=$adobject.distinguishedname;NestedMemberof=@()}
            foreach ($Sid in $ADObject.tokengroups){
                $resultObject.NestedMemberof += ([ADSI]"LDAP://<SID=$SID>").distinguishedname       
            }
            Write-Output $ResultObject      
        }
    }
}

#http://blogs.msdn.com/b/virtual_pc_guy/archive/2010/09/23/a-self-elevating-powershell-script.aspx
function Invoke-AdminPrivilege
{
# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

    # Check to see if we are currently running as an administrator
    if ($myWindowsPrincipal.IsInRole($adminRole))
    {
        # We are running as an administrator, so change the title and background colour to indicate this
        $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";
        $Host.UI.RawUI.BackgroundColor = "DarkBlue";
        Clear-Host;
    }
    else {
        # We are not running as an administrator, so relaunch as administrator

        # Create a new process object that starts PowerShell
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";

        # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
        $newProcess.Arguments = "-noexit & '" + $script:MyInvocation.MyCommand.Path + "'"

        # Indicate that the process should be elevated
        $newProcess.Verb = "runas";

        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess);

        # Exit from the current, unelevated, process
        if ((read-host "Would you like to exit Y/N") -like "Y") {Exit};
    }
}

Function get-HTTPSSlcertBinding {
<#
.DESCRIPTION
    Wrapper command for "netsh http show sslcert" that returns object data
.EXAMPLE
    get-HTTPsSSLcertBinding
#>
    [cmdletbinding()]Param()
    $getSSLCertsCommand = "netsh http show sslcert"
    Write-Verbose "Executing '$getSSLCertsCommand' to retrieve SSL cert bindings"
    $BindingsAsText = Invoke-Expression $getSSLCertsCommand
    $bindings = @()
    $thisbinding = $null
    switch -Regex ($BindingsAsText) {
        '--------------------|SSL'{}
        '^$' {if ($thisbinding){$bindings+=$thisbinding;} $thisBinding = New-Object psobject -Property @{};}
        '^(?<Name>[\w\s]+:?[\w]+)\s+:\s(?<Value>.*)$|^(?<Name>Hostname:port\s+):\s(?<Value>.*)$' {
            $thisBinding | Add-Member -MemberType NoteProperty -Name $matches.name.trim() -Value $matches.value.trim() -Force            
        }
        '^(?<Name>[\w\s]+:[\w]+)\s+:\s(?<Value>.*)$' {
            $thisBinding | Add-Member -MemberType NoteProperty -Name "Name" -Value $matches.value.trim() -Force            
        }
    }
    $bindings | ?{$_.name}
}
function add-HttpsSLCertBinding ([Parameter(Mandatory=$true)]$name="0.0.0.0:443",
                                [Parameter(Mandatory=$true)]$CertificateHash,
                                [Parameter(Mandatory=$true)]$ApplicationID,
                                $CertificateStoreName="MY",
                                $VerifyClientCertRev="Enable",
                                $VerifyRevocationUsingCachedOnly="Disable",
                                $UsageCheck="Enable",
                                $RevocationFreshnessTime="0",
                                $URLRetrievalTimeout="0",
                                $CTLIdentifier="(null)",
                                $CTLStoreName="(null)",
                                $DSMapper="Disable",
                                $NegotiateClientCert="Disable")
{
    <#
    .DESCRIPTION
        Wrapper command for "netsh http add sslcert"

    .PARAMETER Name
        The Name of the binding to add - if it looks like an IP we will add an ipport binding, if it looks like a hostname we will add a hostnameport binding
    #>
    $nameTag = if($name -match '^(\d{1,3}\.){3}\d{1,3}:\d+$') {
        'ipport'
    } elseif ($name -match '^[\w\.]+:\d+$'){
        'hostnameport'
    } else {
        throw "Failed to create Binding '$name', name must be of the format 'IPAddress:Port' or 'Hostname:port'"
        return;
    }
	
    $bindingDetails = @{
		appid=$ApplicationID;
		certhash=$CertificateHash;
        certstorename=$CertificateStoreName;
        verifyclientcertrevocation=$VerifyClientCertRev;
        verifyrevocationwithcachedclientcertonly=$VerifyRevocationUsingCachedOnly;
        usagecheck=$UsageCheck;
        revocationfreshnesstime=$RevocationFreshnessTime;
        urlretrievaltimeout=$URLRetrievalTimeout;
        sslctlidentifier=$CTLIdentifier;
        sslctlstorename=$CTLStoreName;
        dsmapperusage=$DSMapper
        clientcertnegotiation=$NegotiateClientCert
    }


	$bindingDetails.clone().getenumerator() |where-object {$_.name -match '^verify|^dsmapper|^clientcert|usagecheck'}| %{
		$parameter = $_
		switch -regex ($parameter.value)
		{
			'^en'{$bindingDetails.$($parameter.name) = 'enable'}
			'^dis'{$bindingDetails.$($parameter.name) = 'disable'}
			default {throw "$($parameter.name) must be one of 'enable' or 'disable' do not set this parameter to use the default value."}
		}
	}
	
	#Create the new Binding
    $bindingCreatingString = "netsh http add sslcert --% $nametag=$name"
	
	$bindingDetails.getenumerator() |%{
		if ($_.value -ne "(null)" -and  $_.value -ne "0"){
			$bindingCreatingString += " $($_.name)=$($_.value)"
		}
	}
	
    Write-Verbose "Executing '$bindingCreatingString'"
    $CreateResult = Invoke-Expression $bindingCreatingString
    $CreateResult = $Createresult -join ''

    
    if ($createResult -notmatch 'SSL Certificate successfully added'){
        throw "Unable to update '$name'; failed to create the binding, the error was $createResult."
        return;
    }
    get-HTTPSSlcertBinding | ?{$_.name -eq $Name}

}


function set-ldapdata {
  [CmdletBinding(
     SupportsShouldProcess=$true,
    ConfirmImpact="High"
  )] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$DistinguishedName,$RenameObject, [parameter(Mandatory=$False,Position=0,ValueFromRemainingArguments=$True)][Object[]]$Arglist,[string[]]$Clear=@())

    Begin{
        $RenameObjectPlaceHolder = "#RenameADObjectFromParam#"
        $ArgumentList = @{}
         for ($i=0;$i -lt $Arglist.count;$i+=2){
            $name = $Arglist[$i] -replace '^-',''
            $value = $Arglist[$i+1]            
            if ($value -eq $null){
               
            } elseif ($Value.getType().tostring() -notmatch 'System.Management.Automation.ScriptBlock|System.String'){
                $value = [string[]]$value
            }
            $argumentlist.add($name,$value)
            
         }
         if ($RenameObject){
            if ($ArgumentList.count -ne 0 -or $clear){ 
                Write-Warning "Cannot rename and perform attribute updates simultaneously, only the attribute updates will be processed"
            } else {
                $ArgumentLIst.add($RenameObjectPlaceHolder,$RenameObject)
            }
         }
         
    }
    process { 
        foreach ($entry in $DistinguishedName){
            try{
                $updatelist = "Updating $entry "
                $SetInfoRequired = $false
                $thisObject =[ADSI]"LDAP://$entry"                
                foreach ($update in $ArgumentLIst.GetEnumerator()){        
                    $result =$null
                    if ($update.value -ne $null) {        
                        switch -regex ($update.value.gettype().tostring()){
                            'System.String'{
                                $result = $update.value
                                break;
                            }
                            'System.Management.Automation.ScriptBlock'{
                                $result = $thisObject | ForEach-Object $update.value                            
                            }
                        }
                    }
                    if (($result -eq $null -or $result -eq "" -or $update.value -eq $null) -and $update.Name -ne $RenameObjectPlaceHolder){
                        $thisObject.putex(1,$update.name,0)
                        $updatelist += " " + $update.name + ":'" + $result + "'"       
                        $SetInfoRequired = $true
                    } else {
                        switch ($update.name){
                            "#RenameADObjectFromParam#"{
                                $CurrentNameParts = (($entry -replace '\\,','---commahere---') -split ',') | ForEach-Object {$_ -replace '---commahere---','\,'}
                                $ParentOU = $CurrentNameParts[1..100] -join ','                                
                                $Prefix = $CurrentNameParts[0] -replace '([^=]+=).+','$1'
                                if ($result -notmatch "^$([regex]::Escape($prefix))"){$result = $prefix + $result}
                                if ($result -match '[^\\],'){
                                    Write-Error "Renaming '$Entry' to '$result' would result in a naming violation - escape all , with \ eg 'Smith\, John'"                                    
                                } else {
                                    $ParentOUObj =[adsi]"LDAP://$ParentOU"
                                    if ($pscmdlet.ShouldProcess("Rename object $Entry to new name $result")){
                                        $ParentOUObj.moveHere("LDAP://$entry", $result)
                                    }
                                }
                                break;   
                            }                        
                            default {
                                $SetInfoRequired = $true
                                $thisObject.put($update.name,$result)
                                $updatelist += " " + $update.name + ":'" + $result + "'"                            
                            }
                        }
                    }
                }
                foreach ($attributeName in $clear){
                    $thisObject.putex(1,$attributeName,0)
                    $updatelist += " " + $attributeName + ":''"       
                    $SetInfoRequired = $true
                }
                if ($SetInfoRequired){
                     if ($pscmdlet.ShouldProcess($updatelist)){
                        $thisObject.setinfo()
                     }
                }
            } catch {
                Write-Warning "Failed to update $entry, because $_"
            }
        }
    }
    end {
       
    }
}

Function update-HTTPSSlcertBinding {
    
     [cmdletbinding()]Param($name,$RevocationFreshnessTime,$DSMapperUsage,$CtlIdentifier,$CertificateStoreName,$ApplicationID,$VerifyRevocationUsingCachedClientCertificateOnly,$NegotiateClientCertificate,$URLRetrievalTimeout,$CtlStoreName,$CertificateHash,$UsageCheck,$VerifyClientCertificateRevocation)
    $bindingToUpdate = get-HTTPSSlcertBinding | ?{$_.name -eq $Name}
    if (!$bindingToUpdate){
        throw "No binding named '$name' could be found on the local machine"     
        return;
    }
    $bindingToUpdate | fl *    
    $nameToTag = @{
    'Certificate Hash'='certhash'   ;
    'Application ID'='appid' ;                
    'Certificate Store Name'='certstorename' ;        
    'Verify Client Certificate Revocation'='verifyclientcertrevocation'  ;
    'Verify Revocation Using Cached Client Certificate Only'='verifyrevocationwithcachedclientcertonly' ;
     'Usage Check'='usagecheck';
    'Revocation Freshness Time'= 'revocationfreshnesstime';
    'URL Retrieval Timeout'=  'urlretrievaltimeout';
    'Ctl Identifier'='sslctlidentifier' ;
    'Ctl Store Name'='sslctlstorename' ;
    'DS Mapper Usage'='dsmapperusage' ;
    'Negotiate Client Certificate'='clientcertnegotiation'
    }
    $ParamToName = @{}
    $nametoTag.keys | %{
        $ParamToName.add(($_ -replace ' ',''),$_)
    }
   
    $valueTranslater = @{
    'Enabled'='enable';
    'Disabled'='disable'
    }

    $nametag = $bindingToUpdate | Get-Member -MemberType NoteProperty | ?{$_.name -match ':'} |%{$_.name -replace ':',''}
    
    #update the object values to the entry that will be recreated
    foreach ($argument in $PSBoundParameters.GetEnumerator()){
        $($ParamToName.$($argument.key))
        if ($($ParamToName.$($argument.key))){
            $bindingToUpdate.$($ParamToName.$($argument.key)) = $argument.value
        }
    }
        
    #delete the existing binding
    $NetSHDeleteCommand = "netsh http delete sslcert $nametag=$name"
    Write-verbose "Executing '$NetSHDeleteCommand'"
    $DeleteResult = Invoke-Expression $NetSHDeleteCommand
    $DeleteREsult = $DeleteResult -join ''
    if ($DeleteResult -notmatch 'SSL Certificate successfully deleted'){
        throw "Unable to update '$name'; failed to delete the binding, the error was $DeleteResult"
        return;
    }

    #Create the new Binding
    $bindingCreatingString = "netsh http add sslcert --% $nametag=$name"

    $bindingToUpdate | gm | select -expand Name | %{        
        if ($nameToTag.ContainsKey($_) -and $bindingToUpdate.$_ -ne "(null)" -and  $bindingToUpdate.$_ -ne "0"){
            $tag = $nameToTag[$_]
            $value = if ($valueTranslater.ContainsKey($bindingToUpdate.$_)){$valueTranslater[$bindingToUpdate.$_]} else {$bindingToUpdate.$_}
            $bindingCreatingString += " $tag=$value"
        }
    }
    Write-Verbose "Executing '$bindingCreatingString'"
    $CreateResult = Invoke-Expression $bindingCreatingString
    $CreateResult = $Createresult -join ''
    
    if ($createResult -notmatch 'SSL Certificate successfully added'){
        throw "Unable to update '$name'; failed to create the binding, the error was $createResult."
		return;
    }
    get-HTTPSSlcertBinding | ?{$_.name -eq $Name}
}


function find-DisabledInheritance {
  [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$DistinguishedName,[switch]$SkipBaseLevel)
   Begin{
        $results = @()
        $startNum = 0
        if ($SkipBaseLevel) {$startNum = 1}
   }
   process { 
        $DistinguishedName | ForEach-Object{
            $DN = $_ -split ','
            $domParts = $_ -split ",DC="
            $Domain = ($_ -split ",DC=" | select -skip 1) -join "."    
            for ($i=$startNum;$I-lt ($DN.count -$domparts.count);$i++){
                $thisDN = $DN[$i..($DN.count)] -join ","               
                Write-verbose $thisdn
                $acl = ([adsi]"LDAP://$Domain/$thisDN").psbase.objectsecurity
                if ($acl.AreAccessRulesProtected){
                    $results += $thisDN
                    break;
                }
            }
        }
    }
    end {
        $results | select -unique
    }
}


new-alias gssl Retrieve-ServerCertFromSocket
#Write-HOst gssl Retrieve-ServerCertFromSocket


function ConvertTo-Base64 {
    Process {
        foreach ($arg in $args){
            [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($arg))
        }
    }

    
}

function Clip-History {
    get-history | select -expand commandline | clip
}

function ConvertFrom-Base64 {
    process {
        foreach ($arg in $args) {
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($arg))
        }
    }
}

$global:IPTolocation = @{}

function get-IPLocation ($IP){
    if ($IP) {
        if ($global:IPTOlocation.ContainsKey($ip)){
            $global:IPTOlocation.$ip
        } else {
           $global:IPtoLocation.add($ip,(Invoke-WebRequest -UseBasicParsing -Uri "https://extreme-ip-lookup.com/json/$IP" | ConvertFrom-Json))
           $global:IPTOlocation.$ip
        }
     } else {
        $data= (Invoke-WebRequest -UseBasicParsing -Uri "https://extreme-ip-lookup.com/json" | ConvertFrom-Json)
        if (!$global:IPtoLocation.ContainsKey($data.query)){
            $global:IPtoLocation.Add($data.query,$data)
        }
        $data
        
     }
}

function wait-ForEvent($eventID=4114,$ComputerName,$timeout=([timespan]::fromminutes(10))){
  # Step 4 - Wait for Event
  $Waitfor4114Event = {
    $ComputerName = $args[0]
    $timeout = (get-Date) + $args[1]
    $eventID = $args[2]
    
while ((get-date) -lt ($timeout) -and $eventCount -lt 1){
    $eventcount = get-winevent -filterxml @"
    <QueryList>
    <Query Id="0" Path="DFS Replication">
      <Select Path="DFS Replication">*[System[(EventID=$eventID) and TimeCreated[timediff(@SystemTime) &lt;= 3600000]]]</Select>
    </Query>
  </QueryList>  
"@ -MaxEvents 1 -ComputerName $computername -ErrorAction SilentlyContinue| Measure-Object | select -expand Count
    if ($eventCount -lt 1){
        start-sleep -seconds 10
    }

    } 
    return $eventCount
}

    $Waitfor4114EventJob = start-job -ScriptBlock $Waitfor4114Event -ArgumentList $ComputerName,$timeout,$eventID
    start-sleep -seconds 1
    While ($Waitfor4114EventJob.state -eq 'Running'){
        Write-Warning "Waiting for $eventID Event..."
        start-sleep -seconds 30
    }   
    $Waitfor4114EventJob| receive-job
    $Waitfor4114EventJob | remove-job -force
}

function Check-SYSVOLbacklog ($ComputerName='*',$referenceServer){
    $ComputerName = "*$ComputerName*" -replace '\*\*\*','*'
    $DCList =  get-ForestDomainControllers -quickly | ?{$_ -like $ComputerName}     
    
    if ($null -eq $referenceServer){
        $AllDomains = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().domains
        $PDCMap = @{}
        foreach ($Domain in $AllDomains){
            $PDCMap.add($Domain.name,$DOmain.pdcRoleOwner.name)
        }
        $setToProcess = $DCList | %{
            $Domain = $_ -replace '^[^\.]+\.',''
            $ReferenceServer = $PDCMap.$Domain
            new-object psobject -Property @{DC=$_;Reference=$ReferenceServer}
        }

    } else {
        $setToProcess = $DCList | %{ 
            new-object psobject -Property @{DC=$_;Reference=$ReferenceServer}
        }
    }
    $setToProcess | %p{       
        $computer = $_.DC
        $ReferenceServer = $_.reference
        $result = "" | select ComputerName,BackLogCount,Status,Backlog
        $result.ComputerName = $computer
        if ($computer -eq $ReferenceServer){
            $result.status = 'No Backlog against Self'
            return $result
        }
        try {
            
            $REsultData = Get-DfsrBacklog -SourceComputerName $ReferenceServer -DestinationComputerName $computer -GroupName "Domain System Volume" -FolderName 'SYSVOL Share' -Verbose 4>&1 -ErrorAction Stop
            $files = $resultData | select -skip 1
            $result.backlog = $files
            if ($resultdata[0].message -match 'no backlog for the replicated folder'){
                $result.BacklogCount = 0
                $result.status = 'No BackLog'
            } else {
                $result.BackLogCount = [int64]($resultdata[0].message -split ': ' | select -last 1)
                $result.status = "Waiting"
            }
            $Syncing = $files | ?{$_.flags -eq 4} | measure | select -expand count        
            if ($syncing -gt 0){
                $result.status = "$syncing files syncing"
            }
        } catch {
            $oldresult = dfsrdiag backlog /rgname:"Domain System Volume" /rfname:"SYSVOL Share" /smem:$referenceServer /rmem:$computer
            if ($oldresult -match 'Operation Succeeded'){
                if ($oldresult -match 'No Backlog'){
                    $result.BackLogCount = 0
                    $result.Status = "No BackLog"
                } else {                    
                    $result.BackLog = $oldResult
                    $result.Status = 'Unknown'
                    $result.backlogCount =[int64](($oldresult -match 'Backlog File Count: (?<filecount>\d+)')  -split ': ' | select -last 1)
                }
            } else {
                $result.status = "Failed to execute GetDFSRBacklog- Error was $_; also failed to execute using dfsrdiag - result was: $oldresult"
            }
        }
        $result
    } 
}

function Invoke-NonAuthoritativeSysvolRestore ($computername = '.',$timeout = ([timespan]::fromhours(5)) ){
    #https://support.microsoft.com/en-ca/help/2218556/how-to-force-an-authoritative-and-non-authoritative-synchronization-fo
    <#
    The Manual Method
    Step1 -     In the ADSIEDIT.MSC tool modify the following distinguished name (DN) value and attribute on each of the domain controllers that you want to make non-authoritative:
        CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=<the server name>,OU=Domain Controllers,DC=<domain>

        msDFSR-Enabled=FALSE

    Step2 -  Force Active Directory replication throughout the domain.
        Run the following command from an elevated command prompt on the same servers that you set as non-authoritative:

    Step 3 -   DFSRDIAG POLLAD

    Step 4 -  You will see Event ID 4114 in the DFSR event log indicating SYSVOL is no longer being replicated.
        On the same DN from Step 1, set:

    Step 5 -  msDFSR-Enabled=TRUE
        Force Active Directory replication throughout the domain.

        Run the following command from an elevated command prompt on the same servers that you set as non-authoritative:
        DFSRDIAG POLLAD

    Step 6 -   You will see Event ID 4614 and 4604 in the DFSR event log indicating SYSVOL has been initialized. That domain controller has now done a "D2" of SYSVOL.

    #>
    try {
        
        if ($computername -match '^\.$|^localhost$'){
            $system = (Get-WmiObject win32_computersystem)
            $computername = $system.dnsHOstname,$system.Domain -join '.'    
        }

        $DC = get-addomainController $computername    
        #Locate PDC

        # check for backlog

        # Step 1 - Disable DFSR Replication
        Set-Adobject -identity "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,$($DC.ComputerObjectDN)" -replace @{'msDFSR-Enabled'=$false} -Server $computername
        
        # Step 2 - Force AD Replication
        Write-Warning "Forcing Syncall on $ComputerName"
        repadmin /syncall /APd $ComputerName

        # Step 3 - Update config
        Write-Warning "Forcing PollAD on $ComputerName"
        dfsrdiag pollad /Member:$ComputerName
        if ((wait-forevent -eventID 4114 -ComputerName $computername -timeout ([timespan]::fromminutes(2))) -ne 1){
            throw "Timeout waiting for server to disable SYSVOL replication"
        }
    
        # Step 5 - Enable Replication
        Set-Adobject -identity "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,$($DC.ComputerObjectDN)" -replace @{'msDFSR-Enabled'=$true} -Server $computername

        #Step 6 - Wait for Event
        Write-Warning "Forcing PollAD on $ComputerName"
        dfsrdiag pollad /Member:$ComputerName
        if ((wait-forevent -eventID 4614 -ComputerName $computername -timeout ([timespan]::fromminutes(2))) -ne 1){
            throw 'Timeout waiting for server to continue SYSVOL replication'
        }

        if ((wait-ForEvent -eventID 4604 -ComputerName $computername -timeout $timeout) -ne 1){            
            throw 'Timeout waiting for server to finish SYSVOL replication'
        }
    } catch {
        Write-Error "Failed to force Sysvol $_"
    }
}

function AutoType ($Type, $SecondsDelay=1,[switch]$DontGoLastApp,[switch]$clipboard){
    if (!$DontGoLastApp){
        [System.Windows.Forms.SendKeys]::SendWait("%{TAB}")
    }
    if ($clipboard) {
        $Type += get-clipboard
    }
    $type = $type -join "`n"
    start-sleep -seconds $SecondsDelay
    
    for ($i=0;$i-lt $type.length;$i++){
        switch -regex ($type[$i])
        {
            '[%\{\}\(\)~\^\+]' {[System.Windows.Forms.SendKeys]::SendWait("{$($type[$i])}");break}
            "`n" {[System.Windows.Forms.SendKeys]::SendWait("~");break}
            default {[System.Windows.Forms.SendKeys]::SendWait(($type[$i]))}
        }

    }

}

#get-command -CommandType Function |?{$_.Module -eq $null -and $_.name -notmatch ':|importsystemmodules|cd\.\.|cd\\|get-verb|mkdir|more|pause|tabexpansion'} | %{$command = $_;new-object psobject -property @{Name=$command.name;Alias=(get-alias | ?{$_.name -match $command} | select -expand Name)}}

#if(!$MyInvocation.Scriptname) {TryCopyProfile}
$ErrorActionPreference = 'Continue'

cd ([Environment]::GetFolderPath("MyDocuments"))
