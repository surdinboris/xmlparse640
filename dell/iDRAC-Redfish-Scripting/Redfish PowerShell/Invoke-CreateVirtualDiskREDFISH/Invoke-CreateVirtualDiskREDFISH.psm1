<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 1.0
Copyright (c) 2018, Dell, Inc.

This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>




<#
.Synopsis
   Cmdlet used to either get storage controllers, get virtual disks, get physical disks or create virtual disk
.DESCRIPTION
   Cmdlet used to either get storage controllers, get virtual disks, get physical disks or create virtual disk using iDRAC Redfish API.
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
   - get_storage_controllers: Pass in "y" to get current storage controller FQDDs for the server. Pass in "yy" to get detailed information for each storage controller
   - get_virtual_disks: Pass in the controller FQDD to get current virtual disks. Example, pass in "RAID.Integrated.1-1" to get current virtual disks for integrated storage controller
   - get_virtual_disks_details: Pass in the virtual disk FQDD to get detailed VD information. Example, pass in "Disk.Virtual.0:RAID.Slot.6-1" to get detailed virtual disk information
   - get_physical_disks: Pass in the controller FQDD to get physical disks. Example, pass in "RAID.Slot.6-1" to get physical disks. 
   - get_physical_disks_details: Pass in the controller FQDD to get detailed information for physical disks.
   - create_virtual_disk: Pass in the controller FQDD. Example, pass in "RAID.Slot.6-1".
   - raid_level: Pass in the RAID level you want to create. Possible supported values are: 0, 1, 5, 10 and 50. Note: Some RAID levels might not be supported based on your storage controller
   - pdisks: Pass in disk FQDD to create virtual disk, pass in storage disk FQDD, Example: Disk.Bay.2:Enclosure.Internal.0-1:RAID.Mezzanine.1-1. You can pass in multiple drives, just use a comma seperator between each disk FQDD string
   - size: Pass in the size(CapacityBytes) in bytes for VD creation. This is OPTIONAL, if you don't pass in the size, VD creation will use full disk size to create the VD
   - stripesize: Pass in the stripesize(OptimumIOSizeBytes) in kilobytes for VD creation. This is OPTIONAL, if you don't pass in stripesize, controller will use the default value
   - name: Pass in the name for VD creation. This is OPTIONAL, if you don\'t pass in name, storage controller will use the default value

.EXAMPLE
   .\Invoke-CreateVirtualDiskREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -get_storage_controllers y
   This example will return storage controller FQDDs for the server.
.EXAMPLE
   .\Invoke-CreateVirtualDiskREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -create_virtual_disk RAID.Slot.6-1 -raid_level 1 -pdisks Disk.Bay.3:Enclosure.Internal.0-1:RAID.Slot.6-1,Disk.Bay.4:Enclosure.Internal.0-1:RAID.Slot.6-1
   This example will create a RAID 1 for storage controller RAID.slot.6-1 using disk 3 and 4
#>

function Invoke-CreateVirtualDiskREDFISH {


param(
    [Parameter(Mandatory=$True)]
    [string]$idrac_ip,
    [Parameter(Mandatory=$True)]
    [string]$idrac_username,
    [Parameter(Mandatory=$True)]
    [string]$idrac_password,
    [Parameter(Mandatory=$False)]
    [string]$get_storage_controllers,
    [Parameter(Mandatory=$False)]
    [string]$get_virtual_disks,
    [Parameter(Mandatory=$False)]
    [string]$get_virtual_disk_details,
    [Parameter(Mandatory=$False)]
    [string]$get_physical_disks,
    [Parameter(Mandatory=$False)]
    [string]$get_physical_disks_details,
    [Parameter(Mandatory=$False)]
    [string]$create_virtual_disk,
    [Parameter(Mandatory=$False)]
    [string]$raid_level,
    [Parameter(Mandatory=$False)]
    [string]$pdisks,
    [Parameter(Mandatory=$False)]
    [String]$size,
    [Parameter(Mandatory=$False)]
    [string]$stripesize,
    [Parameter(Mandatory=$False)]
    [string]$name
    )

# Function to ignore SSL certs


function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

function check_supported_idrac_version
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage"
    try
    {
    $result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
    }
    catch
    {
    }
	    if ($result.StatusCode -ne 200)
	    {
        Write-Host "`n- WARNING, iDRAC version detected does not support this feature using Redfish API"
	    return
	    }
	    else
	    {
	    }
return
}

Ignore-SSLCertificates

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

check_supported_idrac_version

if ($raid_level -ne "")
{
if ($raid_level -eq 0)
{
$raid_level_string = "NonRedundant"
}
if ($raid_level -eq 1)
{
$raid_level_string = "Mirrored"
}
if ($raid_level -eq 5)
{
$raid_level_string = "StripedWithParity"
}
if ($raid_level -eq 10)
{
$raid_level_string = "SpannedMirrors"
}
if ($raid_level -eq 50)
{
$raid_level_string = "SpannedStripesWithParity"
}
} 

if ($create_virtual_disk -ne "" -and $raid_level -ne "" -and $pdisks -ne "")
{

    if ($pdisks.Contains(","))
    {
    $pdisks_pending=$pdisks.Split(",")
    $pdisks_list=@()
   
        foreach ($item in $pdisks_pending)
        {
        $keys_values=@{"@odata.id"="/redfish/v1/Systems/System.Embedded.1/Storage/Drives/$item"}
        $pdisks_list+=$keys_values   
        }
    }
    else
    {
    $pdisks_list=@()
    $keys_values=@{"@odata.id"="/redfish/v1/Systems/System.Embedded.1/Storage/Drives/$pdisks"}
    $pdisks_list+=$keys_values
    }

    $vd_payload=@{"VolumeType"=$raid_level_string;"Drives"=$pdisks_list} 

    if ($name)
    {
    $vd_payload["Name"] = $name
    }
    if ($size)
    {
    $vd_payload["CapacityBytes"] = [long]$size
    }
    if ($stripesize)
    {
    $vd_payload["OptimumIOSizeBytes"] = [long]$stripesize
    }

    $vd_payload = $vd_payload | ConvertTo-Json -Compress
}

if ($get_virtual_disks -ne "")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/$get_virtual_disks/Volumes"
try
{
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
}
catch
{
Write-Host
$RespErr
return
}

if ($result.StatusCode -eq 200)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully to get virtual disks for {1} controller`n",$result.StatusCode,$get_virtual_disks)
}
else
{
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}

$a=$result.Content
try
{
$regex = [regex] '/Volumes/.+?"'
$allmatches = $regex.Matches($a)
$z=$allmatches.Value.Replace('/Volumes/',"")
$virtual_disks=$z.Replace('"',"")
[String]::Format("- WARNING, virtual disks detected for controller {0}:`n",$get_virtual_disks)

foreach ($i in $virtual_disks)
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/Volumes/$i"
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing
$z=$result.Content | ConvertFrom-Json
if ($z.VolumeType -ne "RawDevice")
{
[String]::Format("{0}, Volume Type: {1}",$z.Id, $z.VolumeType)
}
}
}
catch
{
Write-Host "- WARNING, no virtual disks detected for controller $get_virtual_disks"
}
Write-Host
return

}

if ($get_virtual_disk_details -ne "")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/Volumes/$get_virtual_disk_details"
try
{
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
}
catch
{
Write-Host
$RespErr
return
}

if ($result.StatusCode -eq 200)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully to get virtual disk '{1}' details",$result.StatusCode,$get_virtual_disk_details)
}
else
{
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}
$result.Content | ConvertFrom-Json

return

}


if ($get_storage_controllers -eq "yy")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage"
try
{
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
}
catch
{
Write-Host
$RespErr
return
}
if ($result.StatusCode -eq 200)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully to get storage controller(s)",$result.StatusCode)
}
else
{
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}
$z=$result.Content | ConvertFrom-Json
$number_of_controller_entries=$z.Members.Count
$count=0
Write-Host
while ($count -ne $number_of_controller_entries)
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage"
try
{
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
}
catch
{
Write-Host
$RespErr
return
}
if ($result.StatusCode -ne 200)
{
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}
$z=$result.Content | ConvertFrom-Json
$z=$z.Members[$count]
$z=[string]$z
$z=$z.Replace("@{@odata.id=","")
$z=$z.Replace('}',"")
$u="https://$idrac_ip"+$z
$r = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing
$z=$r.Content | ConvertFrom-Json
[String]::Format("- Detailed information for controller {0} -`n", $z.Id)
$r.Content | ConvertFrom-Json
Write-Host
$count+=1

}
Write-Host
return
}

if ($get_storage_controllers -eq "y")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage"
try
{
$r = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
}
catch
{
Write-Host
$RespErr
return
}
if ($r.StatusCode -eq 200)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully to get storage controller(s)",$r.StatusCode)
}
else
{
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}

$a=$r.Content

Write-Host
$regex = [regex] '/Storage/.+?"'
$allmatches = $regex.Matches($a)
$z=$allmatches.Value.Replace('/Storage/',"")
$controllers=$z.Replace('"',"")
Write-Host "- Server controllers detected -`n"
$controllers
Write-Host
return
}

if ($get_physical_disks -ne "")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/$get_physical_disks"
    try
    {
    $result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }

$z=$result.Content | ConvertFrom-Json
$count = 0
Write-Host "`n- Drives detected for controller '$get_physical_disks' -`n"
$raw_device_count=0
    foreach ($item in $z.Drives)
    {
    $zz=[string]$item
    $zz=$zz.Split("/")[-1]
    $drive=$zz.Replace("}","")
    $u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/Drives/$drive"
    $result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing
    $zz=$result.Content | ConvertFrom-Json
    $zz.id
    }
Write-Host
return
}

if ($get_physical_disks_details -ne "")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/$get_physical_disks_details"
try
{
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr
}
catch
{
Write-Host
$RespErr
return
}
$z=$result.Content | ConvertFrom-Json
$count = 0

foreach ($item in $z.Drives)
{
$zz=[string]$item
$zz=$zz.Split("/")[-1]
$drive=$zz.Replace("}","")
Write-Host "`n- Detailed drive information for '$drive' -`n"
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/Drives/$drive"
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing
$zz=$result.Content | ConvertFrom-Json
$zz
$count++
}

if ($count -eq 0)
{
Write-Host "- WARNING, no drives detected for controller '$get_secure_erase_devices'"
Return
}
Write-Host
Return
}



if ($create_virtual_disk -ne "")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/$create_virtual_disk/Volumes"
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing
$a=$result.Content
$aa=$a | ConvertFrom-Json
$current_vd_count=$aa.Members.Count

$u1 = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/$create_virtual_disk/Volumes"

    try
    {
    $result1 = Invoke-WebRequest -Uri $u1 -Credential $credential -Method Post -Body $vd_payload -ContentType 'application/json' -ErrorVariable RespErr
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }

    if ($result1.StatusCode -eq 202)
    {
    $q=$result1.RawContent | ConvertTo-Json -Compress
    $j=[regex]::Match($q, "JID_.+?r").captures.groups[0].value
    $job_id=$j.Replace("\r","")
    [String]::Format("`n- PASS, statuscode {0} returned to successfully create virtual disk for controller {1}, {2} job ID created",$result1.StatusCode,$create_virtual_disk,$job_id)
    }
    else
    {
    [String]::Format("- FAIL, statuscode {0} returned to create virtual disk",$result1.StatusCode)
    return
    }
}


$u3 ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
$result = Invoke-WebRequest -Uri $u3 -Credential $credential -Method Get -UseBasicParsing -ContentType 'application/json'
if ($result.StatusCode -eq 200)
{
    #[String]::Format("`n- PASS, statuscode {0} returned to successfully query job ID {1}",$result.StatusCode,$job_id)
    
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}
 
$overall_job_output=$result.Content | ConvertFrom-Json

if ($overall_job_output.JobType -eq "RealTimeNoRebootConfiguration")
{
$job_type = "realtime_config"
Write-Host "- WARNING, create virtual disk job will run in real time operation, no server reboot needed to apply the changes"
}
if ($overall_job_output.JobType -eq "RAIDConfiguration")
{
$job_type = "staged_config"
Write-Host "- WARNING, create virtual disk job will run in staged operation, server reboot needed to apply the changes"
}

if ($job_type -eq "realtime_config")
{
    while ($overall_job_output.JobState -ne "Completed")
    {
    $u5 ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
    $result = Invoke-WebRequest -Uri $u5 -Credential $credential -Method Get -UseBasicParsing -ContentType 'application/json'

    $overall_job_output=$result.Content | ConvertFrom-Json
        if ($overall_job_output.Message -eq "Job failed." -or $overall_job_output.Message -eq "Failed")
        {
        Write-Host
        [String]::Format("- FAIL, job not marked as completed, detailed error info: {0}",$overall_job_output)
        return
        }
        else
        {
        [String]::Format("- WARNING, job not marked completed, current status is: {0} Precent complete is: {1}",$overall_job_output.Message,$overall_job_output.PercentComplete)
        Start-Sleep 3
        }
    }
Write-Host
Start-Sleep 10
[String]::Format("- PASS, {0} job ID marked as completed!",$job_id)
Write-Host "`n- Detailed final job status results:"
$u5 ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
$result = Invoke-WebRequest -Uri $u5 -Credential $credential -Method Get -UseBasicParsing -ContentType 'application/json'
$overall_job_output=$result.Content | ConvertFrom-Json
$overall_job_output

$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/$create_virtual_disk/Volumes"
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing

$a=$result.Content
$aa=$a | ConvertFrom-Json
$new_vd_count=$aa.Members.Count

if ($new_vd_count -gt $current_vd_count)
{
Write-Host "- PASS, virtual disk successfully created for storage controller $create_virtual_disk"
}
else
{
Write-Host "- FAIL, virtual disk not successfully created for storage controller $create_virtual_disk"
Return
}
Write-Host
return
}

if ($job_type -eq "staged_config")
{
    while ($overall_job_output.Message -ne "Task successfully scheduled.")
    {
    $u5 ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
    try
    {
    $result = Invoke-WebRequest -Uri $u5 -Credential $credential -Method Get -UseBasicParsing -ContentType 'application/json' -ErrorVariable RespErr
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }
 
    $overall_job_output=$result.Content | ConvertFrom-Json
    if ($overall_job_output.Message -eq "Job failed." -or $overall_job_output.Message -eq "Failed")
    {
    Write-Host
    [String]::Format("- FAIL, job not marked as scheduled, detailed error info: {0}",$overall_job_output)
    return
    }
    else
    {
    [String]::Format("- WARNING, job not marked scheduled, current message is: {0}",$overall_job_output.Message)
    Start-Sleep 1
    }
    }
}
Write-Host "`n- PASS, $job_id successfully scheduled, rebooting server"

$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1"
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing
$z=$result.Content | ConvertFrom-Json
$host_power_state = $z.PowerState

if ($host_power_state -eq "On")
{
Write-Host "- WARNING, server power state ON, rebooting the server to execute staged configuration job"
$JsonBody = @{ "ResetType" = "ForceOff"
    } | ConvertTo-Json -Compress


$u4 = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset"
$result1 = Invoke-WebRequest -Uri $u4 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json'


if ($result1.StatusCode -eq 204)
{
    [String]::Format("- PASS, statuscode {0} returned successfully to power OFF the server",$result1.StatusCode)
    Start-Sleep 15
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}

$JsonBody = @{ "ResetType" = "On"
    } | ConvertTo-Json -Compress


$u4 = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset"
$result1 = Invoke-WebRequest -Uri $u4 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json'

if ($result1.StatusCode -eq 204)
{
    [String]::Format("- PASS, statuscode {0} returned successfully to power ON the server",$result1.StatusCode)
    Write-Host
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}
}
if ($host_power_state -eq "Off")
{
Write-Host "- WARNING, server power state OFF, powering ON server to execute staged configuration job"
$JsonBody = @{ "ResetType" = "On"
    } | ConvertTo-Json -Compress


$u4 = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset"
$result1 = Invoke-WebRequest -Uri $u4 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json'

if ($result1.StatusCode -eq 204)
{
    [String]::Format("- PASS, statuscode {0} returned successfully to power ON the server",$result1.StatusCode)
    Write-Host
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}
}


while ($overall_job_output.JobState -ne "Completed")
{
$u5 ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
try
    {
    $result = Invoke-WebRequest -Uri $u5 -Credential $credential -Method Get -UseBasicParsing -ContentType 'application/json' -ErrorVariable RespErr
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }
$overall_job_output=$result.Content | ConvertFrom-Json
if ($overall_job_output.Message -eq "Job failed." -or $overall_job_output.Message -eq "Failed")
    {
    Write-Host
    [String]::Format("- FAIL, job not marked as completed, detailed error info: {0}",$overall_job_output)
    return
    }
    else
    {
    [String]::Format("- WARNING, job not marked completed, current status is: {0} Precent complete is: {1}",$overall_job_output.Message,$overall_job_output.PercentComplete)
    Start-Sleep 10
    }
}
Start-Sleep 10
Write-Host
[String]::Format("- PASS, {0} job ID marked as completed!",$job_id)
Write-Host "`n- Detailed final job status results:"
$u5 ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$job_id"
$result = Invoke-WebRequest -Uri $u5 -Credential $credential -Method Get -UseBasicParsing -ContentType 'application/json' 
$overall_job_output=$result.Content | ConvertFrom-Json
$overall_job_output
return

}