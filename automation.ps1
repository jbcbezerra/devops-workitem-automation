$ErrorActionPreference = "Stop"
$json_path = Read-Host -Prompt 'Gib den vollen Pfad zu einem json-Template ein'
$json_path = '...template.json'
$data = Get-Content -Raw -Path $json_path | ConvertFrom-Json
function processWorkItem($workItem,$parentIdGiven){
    echo $workItem.title
    # post work item to devops
    # process children of this workitem
    if($workItem.children){
        Foreach ($item in $workItem.children){
            processWorkItem($item)
        }
    }
}
processWorkItem($data)
