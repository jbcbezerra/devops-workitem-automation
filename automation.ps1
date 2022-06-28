[CmdletBinding(DefaultParameterSetName = 'DIR')]
Param(
    [Parameter(Mandatory]
    [Alias('pj')]
    [string]$project,

    [Parameter(Mandatory,
               HelpMessage=".../pat.txt")]
    [string]$pat,

    [Parameter(ParameterSetName = 'DIR',
               Mandatory,
               Position = 2)]
    [Alias('td')]
    [string]$template_dir,

    [Parameter(ParameterSetName = 'ID',
               Mandatory,
               Position =2)]
    [Alias('rid')]
    [string]$rootId,

    [Parameter(ParameterSetName = 'ID',
               Mandatory,
               Position=3)]
    [Alias('cs')]
    [string[]]$children
)
$ErrorActionPreference = "Stop"
# ===================== PREPARATIONS ===================== #

$OrganizationName = "...."
$UriOrganization = "https://dev.azure.com/$($OrganizationName)/"

$ProjectName = $project
$pat_path = $pat # "C:\...\pat.txt"
$AzureDevOpsPAT = Get-Content $pat_path
$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($AzureDevOpsPAT)")) }

# ===================== UTILS ===================== #
function popArrayListAt($arr, $index){
    $val = $arr[$index]
    $arr.RemoveAt($index)
    return $val
}
function arrayListCopy($src,$dst){
    foreach($item in $src){
        [Void]$dst.Add($item)
    }
}

# ===================== FUNCTIONS ===================== #
function validateGroup($workItems){

    # keine duplicate
    $itemNames = [System.Collections.ArrayList]@($workItems.Item1)
    $uniqueItemNames = [System.Collections.ArrayList]@($itemNames | select -Unique)
    if($itemNames.count -ne $uniqueItemNames.count){
        throw "Duplikate Json Datei entdeckt."
    }

    # ----- validate root -----
    # es muss eine root ex.
    $rootItem = [System.Collections.ArrayList]@($workItems | where {$_.Item2.root})
    if($rootItem.Count -ne 1 -and $rootItem.count){
        throw "Es muss GENAU ein WorkItem ex. welches 'root' definiert."
    }
    $rootItem = $rootItem[0].Item2

    # pjson ist nicht in root erlaubt
    if($rootItem.pjson ){
        throw "Das root-Workitem darf nicht 'pjson' definieren"
    }
    # mind. felder
    if(-not $rootItem.type -or -not $rootItem.title){
        throw "Workitems müssen mind. 'type' und 'title' definieren."
    }

    # ----- validate others -----
    $otherItems = [System.Collections.ArrayList]@($workItems | where {-not $_.Item2.root})
    if($rootItem.Count -eq 0){
        return
    }

    foreach ($wi in $otherItems){
        $wiName = $wi.Item1
        $wiItem = $wi.Item2

        # darf kein pid
        if($wiItem.pid){
            throw "Nur root-Workitem darf 'pid' definieren"
        }
        # muss pjson
        if(-not $wiItem.pjson){
            throw "Workitem die nicht root sind müssen 'pjson' definieren"
        }
        # muss mind. type,title
        if(-not $wiItem.type -or -not $wiItem.title){
            throw "Workitems müssen mind. 'type' und 'title' definieren."
        }

        # pjson muss ex.
        $pjsonWI = [System.Collections.ArrayList]@($workItems | where {$wiItem.pjson -eq "./$($_.Item1)"})
        if($pjsonWI.Count -ne 1){
            throw "Der als 'pjson' definierte Workitem: $($wi.pjson) existiert nicht'"
        }
    }

}

function organizeWorkItems($workItems,$proot){
    $depTree = [System.Collections.ArrayList]@()

    if($workItems.count -eq 0){
        return
    }

    $childrenIndexes = 0..($workItems.Count -1) | where {$workItems[$_].Item2.pjson -eq "./$($proot)"}
    if($childrenIndexes.count -eq 0){
        return
    }

    $tmpWorkItems = [System.Collections.ArrayList]@()
    arrayListCopy $workItems $tmpWorkItems
    foreach($i in $childrenIndexes){
        $child = $workItems[$i]
        $tmpWorkItems.Remove($child)

        $retVal = organizeWorkItems $tmpWorkItems $child.Item1
        if($retVal){
            $retVal = [System.Collections.ArrayList]@($retVal)
            $retVal.insert(0,$child)
            [Void]$depTree.Add($retVal)
            foreach($item in $retVal){
                $tmpWorkItems.Remove($item)
            }
        }else{
            [Void]$depTree.Add($child)
        }
    }

    return $depTree
}

function processItemTree($itemTree, $pUrl){
    $gUrl = $null
    for($i=0; $i -lt $itemTree.count; $i++) {
        $workItem = $itemTree[$i]
        if($i -eq 0){
            if($workItem.GetType().Name -ne 'Tuple`2'){
                throw "root oder childroot kann nur ein normales Item sein. Kontrolliere 'organizeWorkItem()'"
            }
            $gUrl = processWorkItem $workItem.Item2 $pUrl
        }
        else {
            switch ($workItem.GetType().Name){
                'Tuple`2' { processWorkItem $workItem.Item2 $gUrl}
                'ArrayList' { processItemTree $workItem $gUrl}
                'Object[]' { processItemTree [System.Collections.ArrayList]@($workItem) $gUrl}
                default { throw "WorkItem Type Error..."}
            }
        }
    }
}

function processWorkItem($workItem,$parentUrl){

    # post work item to devops
    $itemUrl = postWorkItem $workItem $parentUrl

    # process children of this workitem
    if($workItem.children){
        for($i = 0; $i -lt $workItem.children.length; $i++){
            [Void](processWorkItem $workItem.children[$i] $itemUrl)
        }
    }

    return $itemUrl
}

function postWorkItem($workItem, $pUrl){
    if($workItem.GetType().Name -eq 'Tuple`2'){
        $workItem = $workItem.Item2
    }
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
    if($workItem.tags){
        $body = $body + ",
            {
                `"op`": `"add`",
                `"path`": `"/fields/System.Tags`",
                `"value`": `"$($workItem.tags)`"
            }"
    }
    if($workItem.assignedTo){
        $body = $body + ",
            {
                `"op`": `"add`",
                `"path`": `"/fields/System.AssignedTo`",
                `"value`": `"$($workItem.assignedTo)`"
            }"
    }

    if($pUrl){
        $body = $body + ",
            {
                `"op`": `"add`",
                `"path`": `"/relations/-`",
                `"value`": {
                    `"rel`": `"System.LinkTypes.Hierarchy-Reverse`",
                    `"url`": `"$($pUrl)`"
                }
            }"
    }
    $body = $body + "]"

    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $AzureDevOpsAuthenicationHeader -ContentType "application/json-patch+json" -Body $body
    return $response.url
}

# ===================== MAIN ========================== #

# Build json dependency tree
$depTree = [System.Collections.ArrayList]@()

if ( $json_files ) {
    $json_files = [System.Collections.ArrayList]@($json_files)
    if($json_files.count -eq 0){
        throw "Keine jsons definiert"
    }

    $jsonWorkItems = [System.Collections.ArrayList]@()
    foreach($js in $json_files){
        $json = Get-Item $js | Get-Content -Raw | ConvertFrom-Json
        #validateSingleFileGroup $json
        $jsonWorkItems.Add($json)
    }

    foreach($item in $jsonWorkItems){
        
        $parentUrl = $null
        if($item.pid){
            $uri = $UriOrganization + $ProjectName + "/_apis/wit/workitems/" + $item.pid + "?api-version=6.0"
            $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $AzureDevOpsAuthenicationHeader
            $parentUrl = $response.url
        }
        processSingleFileGroupItem $item $parentUrl
    }
}
elseif( $template_dir ){
    $jsons = Get-ChildItem $template_dir -Filter *.json
    $workItems = [System.Collections.ArrayList]@()

    foreach($json in $jsons){
        [Void]$workItems.Add([Tuple]::Create($json.Name,($json | Get-Content -Raw | ConvertFrom-Json)))
    }

    validateGroup $workItems
    $root = $workItems | where {$_.Item2.root}
    $workItems.Remove($root)
    $depTree = [System.Collections.ArrayList]@(organizeWorkItems $workItems $root.Item1)
    $depTree.insert(0,$root)

    $parentUrl = $null
    if($depTree[0].Item2.pid){
        $uri = $UriOrganization + $ProjectName + "/_apis/wit/workitems/" + $depTree[0].Item2.pid + "?api-version=6.0"
        $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $AzureDevOpsAuthenicationHeader
        $parentUrl = $response.url
    }
    processItemTree $depTree $parentUrl
}
elseif ( $rootId ) {
    # Muss Children definieren
    if ( -not $children ) {
        throw "Option -cs muss definiert sein"
    }
    $children = [System.Collections.ArrayList]@($children)
    if($children.count -eq 0){
        throw "Keine children definiert"
    }

    #einlesen aller childrens
    $childrenWorkItem = [System.Collections.ArrayList]@()
    foreach($cs in $children){
        $json = Get-Item $cs | Get-Content -Raw | ConvertFrom-Json
        #validateSingle $json
        $childrenWorkItem.Add($json)
    }

    $parentUrl = $null
    if(-not ($rootId -eq "null")){
        $uri = $UriOrganization + $ProjectName + "/_apis/wit/workitems/" + $rootId + "?api-version=6.0"
        $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $AzureDevOpsAuthenicationHeader
        $parentUrl = $response.url
    }
        
    foreach($wi in $childrenWorkItem){
        processWorkItem $wi $parentUrl
    }
}
else{ throw "input Error"}


