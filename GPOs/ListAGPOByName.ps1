#List all GPOs that contain nolink
Get-GPO -All |
    Where-Object { $_.DisplayName -like '*nolink*' } |
    Select-Object DisplayName, Id

##Listall gpos that contain nolink (change to whatever you want)
