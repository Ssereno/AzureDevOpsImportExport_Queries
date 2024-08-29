# Set up your parameters
$organizationUrl = ""
$projectName = ""
$user = ""
$patToken = ""
$rootFolderPath = ""
$exportDirectory = ""

# Set up the authorization header using the PAT token
$headers = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$patToken)))
}

function InvokeGetRequest ($GetUrl)
{   
    return Invoke-RestMethod -Uri $GetUrl -Method Get -ContentType "application/json" -Headers $headers  
}

# Function to export a single query to a .wiq file
function Export-Query {
    param(
        [string]$queryId,
        [string]$filePath
    )

    $queryUrl = "$organizationUrl/$projectName/_apis/wit/queries/$queryId"+"?`$depth=1&`$expand=all&api-version=7.0"
    $queryResponse = InvokeGetRequest $queryUrl 
    $queryXml = $queryResponse.wiql

    $filePath = "$filePath.wiq"
    [System.IO.File]::WriteAllText($filePath, $queryXml)

    Write-Host "Exported: $filePath"
}

# Function to recursively export all queries in a folder
function Export-Queries-In-Folder {
    param(
        [string]$folderPath,
        [string]$outputDirectory
    )


    $folderUrl = "$organizationUrl/$projectName/_apis/wit/queries/$folderPath"+"?`$depth=1&`$expand=all&api-version=7.0"
    $folderResponse = InvokeGetRequest $folderUrl 
     Write-Host $folderUrl 

    # Create the output directory if it doesn't exist
    if (-not (Test-Path $outputDirectory)) {
        New-Item -ItemType Directory -Force -Path $outputDirectory
    }

    foreach ($item in $folderResponse.children) {
        if ($item.isFolder) {
            # If it's a folder, recurse into it
            $newOutputDir = Join-Path $outputDirectory $item.name
            Export-Queries-In-Folder -folderPath $item.id -outputDirectory $newOutputDir
        } else {
            # If it's a query, export it
            $queryFilePath = Join-Path $outputDirectory $item.name
            Export-Query -queryId $item.id -filePath $queryFilePath

        }
    }
}

# start the export process from the root folder
Export-Queries-In-Folder -folderPath $rootFolderPath -outputDirectory $exportDirectory

