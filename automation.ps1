$ErrorActionPreference = "Stop"


$OrganizationName = "input org-name here"
$UriOrganization = "https://dev.azure.com/$($OrganizationName)/"

# ===================== MAIN ===================== #

$json_path = Read-Host -Prompt 'Gib den vollen Pfad zu einem json-Template ein'
$data = Get-Content -Raw -Path $json_path | ConvertFrom-Json

$ProjectName = Read-Host -Prompt 'Gib den Projektnamen ein'
$pat_path = Read-Host -Prompt 'Gib den Pfad des PersonalAccessToken ein'
$AzureDevOpsPAT = Get-Content $pat_path
$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }



if($data.parentId){
    $uri = $UriOrganization + $ProjectName + "/_apis/wit/workitems/" + $workItem.parentId + "?api-version=6.0"
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $AzureDevOpsAuthenicationHeader
}  
processWorkItems $data $response.url

Clear-Variable -Name ("response","json_path","data","uri")

# ===================== FUNCTIONS ===================== #

function postWorkItem($workItem,$parentUrl){
    $uri = $UriOrganization + $ProjectName + "/_apis/wit/workitems/$" + $workItem.type + "?api-version=6.0"

    $body="[
        {
            `"op`": `"add`",
            `"path`": `"/fields/System.Title`",
            `"value`": `"$($workItem.title)`"
        }"
    if($workItem.description){
        $body = $body + ",
            {
                `"op`": `"add`",
                `"path`": `"/fields/System.Description`",
                `"value`": `"$($workItem.description)`"
            }"
    }

    if($parentUrl){
        $body = $body + ",
            {
                `"op`": `"add`",
                `"path`": `"/relations/-`",
                `"value`": {
                    `"rel`": `"System.LinkTypes.Hierarchy-Reverse`",
                    `"url`": `"$($parentUrl)`"
                }
            }"
    }
    $body = $body + "]"

    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json-patch+json" -Body $body
    return $response.url
}


function processWorkItems($workItem,$parentUrl){
    Write-Host $workItem.title

    # post work item to devops
    $itemUrl = postWorkItem $workItem $parentUrl

    # process children of this workitem
    if($workItem.children){
        for($i = 0; $i -lt $workItem.children.length; $i++){
            processWorkItems $workItem.children[$i] $itemUrl
        }
    }
}
