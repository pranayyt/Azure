[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)] [string] $resourceGroupName,
	[Parameter(Mandatory=$true)] [string] $isTumblingTrgNewDeployment,
  [Parameter(Mandatory=$true)] [string] $instance
)

# halt on first error
$ErrorActionPreference = "Stop"
# print Information stream
$InformationPreference = "Continue"

# if executed from PowerShell ISE
if ($psise) { 
  $rootPath = Split-Path -Parent $psise.CurrentFile.FullPath | Split-Path -Parent
}
else {
  $rootPath = (Get-Item $PSScriptRoot).Parent.FullName
}

#Read the ARM template files
$armFile = Get-ChildItem -Path $rootPath -Recurse -Filter "ARMTemplateForFactory.json" | SELECT -First 1
$armFileWithReplacedValues = $armFile.FullName.Replace($armFile.Name, "ARMTemplate_wReplacedValues.json")

# $instance - for different environments ex. sbx, dev, stg, prod etc
$rsg = 'eva-'+$instance+'-rsg'
$adfv2Name = 'eva-'+$instance+'-adf'
$getAllTriggers =  Get-AzDataFactoryV2Trigger -ResourceGroupName $rsg -DataFactoryName $adfv2Name
$getTumblingWindowTriggers = $getAllTriggers | Where-Object { $_.Properties -like 'Microsoft.Azure.Management.DataFactory.Models.TumblingWindowTrigger'}


$json = Get-Content $armFile.FullName  -raw | ConvertFrom-Json

foreach ($n in $json.parameters) {
	$n | Add-Member -Type NoteProperty -Name 'isTumblingTrgNewDeployment' -Value  @{
		type= "bool"
      	defaultValue= [System.Convert]::ToBoolean($isTumblingTrgNewDeployment)
	}
}

foreach ($n in $json.resources){
	$json.update |  % { 
		$todaysDate = Get-Date 
		if ($n.properties.type -like 'TumblingWindowTrigger' -and $n.type -notlike "Microsoft.DataFactory/factories/integrationRuntimes"){
			foreach ($item in $getTumblingWindowTriggers) {
				if ($n.name.ToLower().Contains($item.Name.ToLower())){
					if ($item.Properties.StartTime -ne $n.properties.typeProperties.StartTime){

						if ($item.RuntimeState -eq 'Started'){
							$activeTrigger = $item | Where-Object { $_.RuntimeState -like 'Started'}
							$allactiveTriggerRuns =  Get-AzDataFactoryV2TriggerRun -Name $activeTrigger.name -ResourceGroupName $rsg -DataFactoryName $adfv2Name -TriggerRunStartedAfter $item.Properties.StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ") -TriggerRunStartedBefore $todaysDate.ToString("yyyy-MM-ddTHH:mm:ssZ")  | Select-Object -Last 1
							if (![string]::IsNullOrEmpty($allactiveTriggerRuns)){
								if ("[concat(parameters('factoryName'), '/$($item.Name)')]" -in $n.name ){
									$n.properties.typeProperties.StartTime = $allactiveTriggerRuns.TriggerRunTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ")
								}
							}
							else{
								if ("[concat(parameters('factoryName'), '/$($item.Name)')]" -in $n.name ){
									$n.properties.typeProperties.StartTime = $n.properties.typeProperties.StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
								}
							}
						}else{
							$inactiveTrigger = $item | Where-Object { $_.RuntimeState -like 'Stopped'}
							$allInactiveTriggerRuns =  Get-AzDataFactoryV2TriggerRun -Name $inactiveTrigger.name -ResourceGroupName $rsg -DataFactoryName $adfv2Name -TriggerRunStartedAfter $item.Properties.StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ") -TriggerRunStartedBefore $todaysDate.ToString("yyyy-MM-ddTHH:mm:ssZ")  | Select-Object -Last 1
							if (![string]::IsNullOrEmpty($allInactiveTriggerRuns)){
								if ("[concat(parameters('factoryName'), '/$($item.Name)')]" -in $n.name ){
									$n.properties.typeProperties.StartTime = $allInactiveTriggerRuns.TriggerRunTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ")
								}
							}
							else{
								if ("[concat(parameters('factoryName'), '/$($item.Name)')]" -in $n.name ){
									$n.properties.typeProperties.StartTime = $n.properties.typeProperties.StartTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
								}
							}
						}
						
						 $item | ForEach-Object { Stop-AzDataFactoryV2Trigger -ResourceGroupName $rsg -DataFactoryName $adfv2Name -Name $item.Name -Force 
						 	Start-Sleep -s 2
						 }
						 Remove-AzDataFactoryV2Trigger -Name $item.Name -ResourceGroupName $rsg -DataFactoryName $adfv2Name -Force -Verbose -ErrorAction Continue
						
						
					}else{
						if ("[concat(parameters('factoryName'), '/$($item.Name)')]" -in $n.name ){
								$n | Add-Member -Type NoteProperty -Name 'condition' -Value '[parameters(''isTumblingTrgNewDeployment'')]' -Force
							}
					}
				}
				
			}			
		}
	}
}

$json | ConvertTo-Json -depth 100 | Out-file $armFileWithReplacedValues
