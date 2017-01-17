#
# Disk_and_MountPoint_Space.ps1
#
#
# Specify the folder, servernames file and the desired output csv file
$DataFolder = "D:\Personal\OneDrive\Projects\Projects-PowerShell\OperatingSystem\OperatingSystem\DataFiles\"
$ServerListFile  = $DataFolder + "AllServers.txt"
$DiskSizeOutputCsv = $DataFolder + "DiskSizes.csv"

# Create a data table
$Table = New-Object System.Data.DataTable "VolData"
$Table.columns.add((New-Object system.Data.DataColumn ServerName,([string])))
$Table.columns.add((New-Object system.Data.DataColumn Path,([string])))
$Table.columns.add((New-Object system.Data.DataColumn SizeGB,([decimal])))
$Table.columns.add((New-Object system.Data.DataColumn FreeGB,([decimal])))
$Table.columns.add((New-Object system.Data.DataColumn Type,([string])))

# For each server in the list supplied..
foreach ($ServerName in (Get-Content $ServerListFile)) 
{
	# Get the FQDN
	$ServerNameFQDN = (Get-WmiObject -class "win32_computersystem" -ComputerName $ServerName).DNSHostName.ToUpper()+"."+(Get-WmiObject -class "win32_computersystem" -ComputerName $ServerName).Domain

	# Get the sizes of the volumes
	$Volumes = Get-WMIObject -class "win32_volume" -namespace "root/cimv2" -ComputerName $ServerName |  Where-Object {$_.FileSystem} | select PSComputerName, Name, Capacity, Freespace, FileSystem, BlockSize 
	$Volumes | Where-Object {$_.Name -match "^[A-Z]:\\$"} | % {$row = $Table.NewRow(); $row.ServerName = $ServerNameFQDN; $row.Path = $_.Name; $row.SizeGB = [math]::Round($_.Capacity/1gb); $row.FreeGB = [math]::Round($_.Freespace/1gb,2); $row.Type = "Volume"; $Table.Rows.Add($row) }

	#Get a list of mount points
	$MountPoints = Get-WMIObject -class "win32_mountpoint" -namespace "root\cimv2" -computername $ServerName  
	foreach ($MountPoint in $Mountpoints) 
	{  
		# Find the directory of each mount point
		$MountPoint.Directory = $MountPoint.Directory.replace("\\","\")    
		foreach ($Volume in $Volumes) 
		{  
			# Go through each known volume ache check if the volume name matches the directory name
            $VolumeName =  $Volume.name.Substring(0,$Volume.name.length-1) 
            if ($MountPoint.Directory.contains("""$VolumeName""")) 
			{
				# If so collect the sizes of the that volume 
				$MountPointFolder = $VolumeName 
				$row = $Table.NewRow(); $row.ServerName = $ServerNameFQDN; $row.Path = $MountPointFolder; $row.SizeGB = [math]::Round($Volume.Capacity/1GB,2); $row.FreeGB = [math]::Round($Volume.Freespace/1GB,2); $row.Type = "MountPoint"; $Table.Rows.Add($row)
		    }
		}  
	}
}

# Write the data tabale to a csv
$Table| Export-Csv "D:\Personal\OneDrive\Projects\Projects-PowerShell\OperatingSystem\OperatingSystem\DataFiles\DiskSizes.csv" -Force