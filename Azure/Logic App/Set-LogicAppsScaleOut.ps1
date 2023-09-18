Connect Az-Account

Set-AzAContext -SubscriptionId "<subscription-id>"

$logicAppNames = @('')

#Iterate over logic App Names
foreach($logicAppName in $logicAppNames){
    $logicApp = Get-AzLogicApp $logicAppName

    $logicApp.Definition.properties.definition.triggers.ForEach({$_.minItems = 1})

}