
# Set up your parameters
$organizationUrl = "<your project url>"
$targetProjectName = "<your  project name>"
$user = "<user>"
$patToken = "<pat>"
$targetRootFolderPath = ""
$importDirectory = ""

$queryObject = [PSCustomObject]@{
    name = $null
    wiql = $null
    columns = $null
    sortColumns = $null
}

# Set up the authorization header using the PAT token
$headers = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$patToken)))
}


function InvokePostRequest ($PostUrl, $body)
{   
    return Invoke-RestMethod -Uri $PostUrl -Method Post -ContentType "application/json" -Headers $headers -Body $body
}


# Function to create a folder in Azure DevOps
function Create-Folder {
    param(
        [string]$folderPath
    )

    $folderName = [System.IO.Path]::GetFileName($folderPath)
    $parentFolderPath = [System.IO.Path]::GetDirectoryName($folderPath)

    $folderUrl = "$organizationUrl/$targetProjectName/_apis/wit/queries/$parentFolderPath"+"?api-version=7.0"
    
    $body = @{
        "name" = $folderName
        "isFolder" = $true
    } | ConvertTo-Json

    try {
        $response = InvokePostRequest $folderUrl $body
        Write-Host "Created folder: $folderPath"
    } catch {
        Write-Host "Folder creation failed (might already exist): $folderPath"
    }
}

# Function to create a query in Azure DevOps
function Import-Query {
    param(
        [string]$queryFilePath,
        [string]$folderPath
    )

    $queryName = [System.IO.Path]::GetFileNameWithoutExtension($queryFilePath)
    $wiql = Get-Content -Path $queryFilePath -Raw

    $queryUrl = "$organizationUrl/$targetProjectName/_apis/wit/queries/$folderPath"+"?api-version=5.0"
    $queryObject.name = $queryName.ToString(); 
    $queryObject.wiql = $wiql.ToString();

    $body = ConvertTo-Json $queryObject 

    try {
        $response = InvokePostRequest $queryUrl $body
        Write-Host "Imported query: $queryName into $folderPath"
    } catch {
        Write-Host "Query creation failed: $queryName. Error: $($_.Exception.Message)"
    }
}

# Function to recursively import queries from a folder
function Import-Queries-From-Folder {
    param(
        [string]$localFolderPath,
        [string]$azureFolderPath
    )

    # Create the corresponding folder in Azure DevOps
    Create-Folder -folderPath $azureFolderPath

    # Import each .wiq file as a query
    foreach ($file in Get-ChildItem -Path $localFolderPath -Filter *.wiq) {
        Import-Query -queryFilePath $file.FullName -folderPath $azureFolderPath
    }

    # Recurse into subfolders
    foreach ($subfolder in Get-ChildItem -Path $localFolderPath -Directory) {
        $newAzureFolderPath = "$azureFolderPath/$($subfolder.Name)"
        Import-Queries-From-Folder -localFolderPath $subfolder.FullName -azureFolderPath $newAzureFolderPath
    }
}

# Start importing from the root directory
Import-Queries-From-Folder -localFolderPath $importDirectory -azureFolderPath $targetRootFolderPath
