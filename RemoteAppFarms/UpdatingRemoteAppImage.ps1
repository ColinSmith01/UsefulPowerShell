### 1. Find Active broker if you have HA

Import-Module RemoteDesktop

$Broker = (Get-RDConnectionBrokerHighAvailability -ConnectionBroker "chorcb02.cho.corp.ryanair.com").ActiveManagementServer

$Broker


### 2. Find alias name etc for the RemoteApp youre updating or making Finance for example

Get-RDRemoteApp -ConnectionBroker $Broker -CollectionName "You-Need-Your-CollectionName" |
    Select-Object Alias, DisplayName, IconPath, IconIndex


#### 3. Update the Icon 

Set-RDRemoteApp -ConnectionBroker $Broker -CollectionName "Finance" -Alias "start_banking" -IconPath "C:\Program Files (x86)\BANKING\ARPPRODUCTICON.exe" -IconIndex 0

### 4. Confirm update of Image working 

Get-RDRemoteApp -ConnectionBroker $Broker -CollectionName "Finance" -Alias "start_banking" |
    Select-Object Alias, DisplayName, IconPath, IconIndex

<#Expected result
Alias      DisplayName         IconPath                                                              IconIndex
-----      -----------         --------                                                              ---------
start_chmi CHMI Primary 30.0.0 C:\Program Files (x86)\BANKING\ARPPRODUCTICON.exe                       0
#>

<##Anything else?
Ensure the icon source exists at the same local path on all Session Hosts in the collection. List them with:
powershell #>

Get-RDSessionHost -ConnectionBroker $Broker -CollectionName "Finance" |
    Select-Object SessionHost
    
