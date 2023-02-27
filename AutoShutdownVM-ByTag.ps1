try
{
	# Ensures you do not inherit an AzContext in your runbook
	$null = Disable-AzContextAutosave -Scope Process
    "Logging in to Azure..."
	# Connect to Azure with system-assigned managed identity
	$AzureContext = (Connect-AzAccount -Identity).context
	Write-Output $AzureContext
    Write-Output $AzureContext.Subscription
	# Set and store context
	$AzureContext = Set-AzContext -Subscription $AzureContext.Subscription -DefaultProfile $AzureContext
    "Logged in."
}
catch {
    if (!$AzureContext)
    {
        $ErrorMessage = "Connection $AzureContext not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$ShutdownVMs = Get-AzResource -ResourceType Microsoft.Compute/virtualMachines | Select-Object Name,ResourceGroupName,@{Label="Tags-AutoShutdown";Expression={$_.Tags["AutoShutdown"]}} | Where-Object Tags-Autoshutdown -ne "False"
$ShutdownVMs = $ShutdownVMs | Get-AzVM -status | Select-Object Name,ResourceGroupName,@{Label="Status";Expression={$_.Statuses[1].DisplayStatus}} | Where-Object {($_.Status -ne "VM deallocated") -and ($_.Status -ne "VM deallocating")}
Write-Output "Shutdown virtual machines summary:`n "$ShutdownVMs.Name" `n"

Foreach ($ShutdownVM in $ShutdownVMs){
    Write-Output "Working on... $ShutdownVM"
    $ShutdownVM | Stop-AzVM -Force -NoWait
}

