$ProfileVersion = "1.18"
$ErrorActionPreference = 'SilentlyContinue'
Write-output "Loading version $ProfileVersion"
<#
 md $profile.CurrentUserAllHosts | out-null
 rd $profile.CurrentUserAllHosts
 notepad $profile.currentUserallhosts

 . $profile.currentuserallhosts

#>

function TryCopyProfile {
    #Stab this into my profile
    if (!(test-path $profile.CurrentUserAllHosts)){
        md $profile.CurrentUserAllHosts | out-null
        rd $profile.CurrentUserAllHosts
    }
    try {
        $wc = New-Object System.Net.WebClient;$wc.DownloadFile('http://www.wrish.com/scripts/profile.ps1',"$env:TEMP\profiletemp.tmp")        
        if (((get-item $profile.CurrentUserAllHosts -ea 0) -eq $null) -or ((get-item $env:TEMP\profiletemp.tmp).length -gt 0 -and (get-item $env:TEMP\profiletemp.tmp).length -ne (get-item $profile.CurrentUserAllHosts).length)){
            Write-Host "Updating Profile"
            move-item $env:TEMP\profiletemp.tmp $Profile.CurrentUserAllHosts -force
            . $Profile.CurrentUserAllHosts
        }           
    } catch {Write-Error "Profile Update failed because $_"}
    finally{
         $wc.Dispose()
    }
}

function list-ProfileFunctions ($regex='^###########$') {
    get-content $profile.currentuserAllhosts | select-string "^function|^New-Alias" |%{$_ -replace '^function|^New-Alias','' -replace '\{.*',''}| sort | ho $regex
}
New-Alias lf list-ProfileFunctions
Write-host lf list-ProfileFunctions


#Get a new Secure Credential and store it in encrypted format to a file
Function Stored-Credential($name, [switch]$New, [switch]$check)
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
        $Credential = get-credential -Message "Enter credential to be stored for $name";
        
        #Create a simple object
        $XMLCredential = new-object psobject -Property @{
             "user"=$credential.username;
             "password"=($credential.password | ConvertFrom-SecureString );           
        }
        $XMLCredential | export-clixml -Path $pathToCred        
        return $Credential
    }        
}

Write-Host "Stored-Credential"

function backup-ADFSConfiguration ($path =".\"){
    get-command get-adfs* | %{$cmd = $_.name; $file = "$cmd.xml"; Invoke-Expression -command "$cmd | export-clixml $file"} 
}
Write-Host "backup-ADFSConfiguration"

function lctc {
(get-history)[-1].commandline | clip
}
Write-Host "lctc"

function search-history ($regex,[switch]$ShowAll){

    if ($showall) {
        get-history -count 32767 | ft ID,Commandline -AutoSize | ho $regex
    } else {
        get-history -count 32767 | ?{$_.commandline -match $regex}| ft ID,Commandline -AutoSize | highlight-output $regex
    }

}
Write-Host "Search-History"

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
Write-Host "ADFSClipFilter"


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
Write-Host "Highlight-String"

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
Write-Host "Highlight-Output Alias:HO"

#Create  HO as an alias; Get-childitem | ho "\w+\.doc"
new-alias ho highlight-output 

$Global:O365Connected = ""
function connect-MSOL ($name, [switch]$new)
{
	Import-Module MSOnline
	$O365Cred = Stored-Credential $name -new:$new
	$O365Session = New-PSSession –ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell -Credential $O365Cred -Authentication Basic -AllowRedirection
	Import-PSSession $O365Session -allowclobber
	Connect-MsolService –Credential $O365Cred
	$Global:O365Connected = $name

}
new-alias cm connect-MSOL 
Write-Host "Connect-MSOL Alias:CM"

 function prompt {

	"$($Global:O365Connected) $(get-location)>"

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
     $NameProperty = @("displayName","userprincipalname","samaccountname","*name"),     
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
            foreach ($row in $CObject){
                $Objs = get-member -inputobject $row -memberType NoteProperty;
                $value = "!!!!NOTHING!!!!!"
                foreach ($member in $objs){
                    if ($member.name -ne "Property" -and $row.$($member.name) -ne $value -and $value -ne "!!!!NOTHING!!!!!"){ $row; break;} 
                    elseif($member.name -eq "Property") {}
                    else {$value = $row.$($member.name);}
                }             
            }
            
        } else {
            $CObject    
        }
    }
}


new-alias csbs Compare-SideBySide 
Write-Host "Compare-SideBytSide Alias:csbs"

Function Port-Ping {
    param([Array]$hostlist,[Array]$ports = $(80,443,389,636,3268),[Int]$timeout = "50")
    $ErrorActionPreference = "SilentlyContinue"
    $ping = new-object System.Net.NetworkInformation.Ping
    foreach ($ip in $hostlist) {
        $rslt = $ping.send($ip,$timeout)
        if (! $?){
            Write-Host "Host: $ip - not found" -ForegroundColor Red
        }
        else {
            write-host "Host: $ip " -NoNewline
            if ($rslt.status.tostring() –eq “Success”) {
                write-host "ICMP " -ForegroundColor Green -NoNewline
            } else
            {
                write-host "ICMP " -ForegroundColor Red -NoNewline
            }
            write-host " TCP " -NoNewline   
                foreach ($port in $ports){
                    $socket = new-object System.Net.Sockets.TcpClient($ip, $port)
                    if ($socket –eq $null) {
                        write-host "$port," -ForegroundColor Red -NoNewline
                    }
                    else {
                        write-host "$port,"-foregroundcolor Green -NoNewline
                        $socket = $null
                    }
                }

        }
        Write-Host 
    }    
}

Write-Host "Port-Ping"

Function Test-Port ($DestinationHosts,$Ports,[switch]$noPing,$pingTimeout="2000",[switch]$ShowDestIP) { 
  
    
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

     $maxthreads = 5;
     $iss = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
     $pool = [Runspacefactory]::CreateRunspacePool(1, $maxthreads, $iss, $host)
     $pool.open()
     $threads = @()
     $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($Script_CheckPort.toString())

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
    $pool.close()  
    $iss = $null
    $threads = $null
    $scriptblock = $null


}

new-alias tp Test-Port 
Write-Host "Test-Port Alias:tp"

new-alias pp Port-Ping 
Write-Host "Port-Ping Alias:pp"
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
Write-Host "get-adsite"


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
                    [Parameter(Mandatory=$false)][string[]]$ImportFunctions
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
                    $scriptblock = [scriptblock]::Create("param(`$_)`r`n" + $functionSet + $Scriptblock.ToString())
                    Write-debug $scriptblock.tostring()               
                }
                PROCESS {
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
                }
                END {
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
                    }
                }
            }

New-Alias %p ForEach-Parallel
Write-host Foreach-Parallel Alias:%p
            
function get-ForestDomainControllers ()
{
    $mresult = @()
    $AllDomains = ([System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()).domains 
    Foreach ($domain in $alldomains){
        $mresult += get-addomaincontroller -filter * -server $domain.name | select Domain,Name,hostname,site,OperatingSystem,Ipv4Address;
    }
    return $mresult;
}
Write-host Get-forestDomainControllers

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

Write-host get-adsite

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

Write-host get-adsitelink

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
        $subnetObject | add-member -name Site -value ([ADSI]("LDAP:/$Server/$($SubnetObject.siteObject)")).cn[0] -MemberType NoteProperty
        write-output $SubnetObject
    }
}

write-host get-adsubnet

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
write-host get-adconfServer

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

write-host get-adConnection

function Check-ForestReplications {
    get-ForestDomainControllers | ForEach-Parallel {                
        $replresult = repadmin /showrepl $_.hostname /csv
        write-output (new-object psobject -Property @{server=$_.hostname;ReplResults=$replResult})
    }
}



write-host Check-ForestReplications

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
Write-Host get-adDevice

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
Write-Host get-ADDeviceContainer
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
    $activity = "Remove profile for user $($profile.SID) from computer $Computername with local path $($profile.localpath)"
    if ($pscmdlet.ShouldProcess($activity)) {
        Write-Verbose "Attempting to $activity"
        $profile.Delete()       
    }
  }
}
write-host cleanupuserprofiles

function Open-profile { 
    if (! (Test-Path $profile.CurrentUserAllHosts)){
        md $profile.CurrentUserAllHosts
        rd $profile.CurrentUserAllHosts
    }

    notepad $profile.CurrentUserAllHosts
    }
write-host Open-profile 

function get-ldapData ($ldapfilter,$searchRoot,$Server,[switch]$GC,$Enabled,$passwordNotRequired,$CannotChangePassword,$PasswordNeverExpires,$TrustedForDelegation,$O365Find,$pageSize=1000,$Properties="*",$sizeLimit=0,[switch]$verbose)
<#
.DESCRIPTION
Wrapper for the LDAP searcher that allows easy searching on any attribute using a parameter

.PARAMETER LDAPFilter
Enter any standard LDAP filter here eg "|(objectclass=user)(objectclass=computer)". Note that any

.PARAMETER SearchRoot
The base to start searching from, by default this is the root of the domain. If the GC is selected this will be the root of the forest. 

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
get-ldapdata -extensionAttribute10 -GC

Search the the global catalog from the root of the forest for any object with extensionattribute10 set to any value

.EXAMPLE 
get-ldapdata -givenName Joe -sn Smith -objectclass user -gc

Search the global catalog for any user object with a given name = Joe and Lastname equal Smith

.INFO
Version 1.1 Updated to resolve exchange guids, objectSids and process useraccountcontrolflags
Version 1.2 updated to add referral chasing

#>
{
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
        $ldapfilter += "(|(userprincipalname=$o365Find)(proxyaddresses=SMTP:$O365Find)(mail=$O365Find)(proxyaddresses=SIP:$O365Find)(msrtcsip-primaryuseraddress=SIP:$O365Find))"
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
    

    $ldapfilter = "(&$ldapfilter)"
    Write-Verbose "Filter being used $ldapfilter"
    
    
    #Connect to the Domain and setup the searcher
    $AdSearcher = [adsisearcher]$ldapfilter
    $AdSearcher.Searchroot = [ADSI]("$protocol/$Server/$Searchroot")
    Write-Verbose ("Searchroot: " + $ADSearcher.SearchRoot.path.tostring())
    $ADSearcher.PageSize = $pageSize
    $ADSearcher.Sizelimit = $sizeLimit
    $adsearcher.ReferralChasing = [DirectoryServices.ReferralChasingOption]::All    
    $properties | %{$ADSearcher.PropertiesToLoad.Add($_) | out-null}   
    
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
                     'badpasswordtime|lastlogontimestamp|lockouttime'{
                        $PropertyValue =   [datetime]::fromfiletime($LDAPResult.properties.$property[0])
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
write-host Listen-Port

function Check-ADFSFederationForAllDomains {
    
    get-msoldomain | ?{$_.authentication -eq "Federated" -and !$_.rootDomain } | %{
        Write-host Processing $_.Name
        $SETUP = Get-MsolFederationProperty –DomainName $_.Name
        if ($setup[0].TokenSigningCertificate -eq $setup[1].TokenSigningCertificate -and $setup[0].NextTokenSigningCertificate -eq $setup[1].NextTokenSigningCertificate){
            Write-host $_.Name "Token Signing and Next Token Signing Certificates Match" -ForegroundColor Green      
         } else {
            Write-host $_.Name "Token Signing and/or Next Token Signing Certificates DO NOT Match" -ForegroundColor REd    
         }
      } 
}
write-host 'Check-ADFSFederationForAllDomains'

Function Update-ADFSFederationForAllDomains ($supportMultipleDomains){
    
    get-msoldomain | ?{$_.authentication -eq "Federated" -and !$_.rootDomain } | %{
        Write-host Processing $_.Name
        Update-MsolFederatedDomain –DomainName $_.Name -SupportMultipleDomain:$supportMultipleDomains
       
      } 
}
Write-Host 'Update-ADFSFederationForAllDomains' 
Function get-HTTPSSlcertBinding (){
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
Write-Host 'get-HTTPSSlcertBinding'

Function update-HTTPSSlcertBinding ($name,$CertificateHash,$ApplicationID,$CertificateStoreName,$VerifyClientCertRev,$VerifyRevocationUsingCachedOnly,$UsageCheck,$RevocationFreshnessTime,$URLRetrievalTimeout,$CTLIdentifier,$CTLStoreName,$DSMapper,$NegotiateClientCert){
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

    $valueTranslater = @{
    'Enabled'='enable';
    'Disabled'='disable'
    }

    $nametag = $bindingToUpdate | Get-Member -MemberType NoteProperty | ?{$_.name -match ':'} |%{$_.name -replace ':',''}
    
    #update the object values to the entry that will be recreated
    if ($CertificateHash) {$bindingToUpdate.'Certificate Hash' = $CertificateHash}

    #delete the existing binding
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
    $CreateResult = Invoke-Expression $bindingCreatingString
    $CreateResult = $Createresult -join ''
    
    if ($createResult -notmatch 'SSL Certificate successfully added'){
        throw "Unable to update '$name'; failed to create the binding, the error was $createResult."
    }
    get-HTTPSSlcertBinding | ?{$_.name -eq $Name}
}
Write-Host 'update-HTTPSSlcertBinding'



function get-ImmutableIDfromADObject
{
    [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]$ADObject) 
   process{ 
        if (!$ADObject.objectguid){$ADObject = get-adobject $AdObject -properties objectGuid}
        [system.convert]::ToBase64String($ADObject.objectguid.tobytearray())
    }
}

function get-ADObjectFromImmutableID{
      [CmdletBinding()] Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$ImmutableID)
   process { get-adobject  ([guid]([system.convert]::FromBase64String($ImmutableID)))}
}

Write-Host 'get-ImmutableIDfromADObject'
write-host 'get-ADObjectFromImmutableID'

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

Write-Host 'CreateArrayFromPastedText'


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
            $ADuser = get-aduser $userIdentity -Properties memberof,distinguishedname,primaryGroup
            write-output (new-object psobject -property @{distinguishedname=$aduser.distinguishedname;'NestedMemberOf'=(@(enumerateMemberof $ADuser)+(enumerateMemberof (get-adgroup $AdUser.primaryGroup -properties memberof)))})
        }
    }
}
Write-Host get-adNestedMembership

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

new-alias gssl Retrieve-ServerCertFromSocket
write-host gssl Retrieve-ServerCertFromSocket

#get-command -CommandType Function |?{$_.Module -eq $null -and $_.name -notmatch ':|importsystemmodules|cd\.\.|cd\\|get-verb|mkdir|more|pause|tabexpansion'} | %{$command = $_;new-object psobject -property @{Name=$command.name;Alias=(get-alias | ?{$_.name -match $command} | select -expand Name)}}

if(!$MyInvocation.Scriptname) {TryCopyProfile}
$ErrorActionPreference = 'Continue'

cd $env:USERPROFILE\documents
