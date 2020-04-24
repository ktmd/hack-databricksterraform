param([String]$type)

if ($ENV:debug_log) {
    Start-Transcript -Path "./secretscope.$type.log"
}

# Terraform provider sends in current state
# as a json object to stdin
$stdin = $input

# Vars
# 
# Databricks workspace endpoint
$databricksWorkspaceEndpoint = $env:DATABRICKS_HOST
$patToken = $env:DATABRICKS_TOKEN
$scopeName = $env:secret_scope_name
$scopeInitialManagePrincipal = $env:initial_manage_principal

$headers = @{
    "Authorization" = "Bearer $patToken"
}

function create {
    Write-Host "Starting create"
    
    $response = Invoke-WebRequest $databricksWorkspaceEndpoint/api/2.0/secrets/scopes/create `
        -Headers $headers `
        -Method 'POST' `
        -ContentType 'application/json; charset=utf-8' `
        -Body @"
        {
            "scope": "$scopeName",
            "initial_manage_principal": "$scopeInitialManagePrincipal"
        }
"@

    test-response $response

    write-host $response.Content

    Write-host @"
    {
        "name": "$scopeName",
    }
"@
}

function read {
    Write-Host "Starting read"


    $response = Invoke-WebRequest $databricksWorkspaceEndpoint/api/2.0/secrets/scopes/list `
        -Headers $headers `
        -Method 'GET' `
        -ContentType 'application/json; charset=utf-8'

    $scopes = $response.Content | ConvertFrom-JSON | select-object -expandProperty scopes

    foreach ($scope in $scopes) {
        if ($scope.name -eq $scopeName) {
            $json = $scope | ConvertTo-Json
            Write-Host "Found scope:"
            Write-Host $json
            return
        }
    }

    Write-Error "'$name' not found in workspace!"
}

function update {
    Write-Host "Starting update (calls delete then create)"
    delete
    create
}

function delete {
    Write-Host "Starting delete"


    $response = Invoke-WebRequest $databricksWorkspaceEndpoint/api/2.0/secrets/scopes/delete `
        -Headers $headers `
        -Method 'POST' `
        -ContentType 'application/json; charset=utf-8' `
        -Body "{`"scope`": `"$scopeName`"}"

    test-response $response
}

function test-response($response) {
    if ($response.StatusCode -ne 200) {
        Write-Error "Request failed. Status code: $($response.StatusCode) Body: $($response.RawContent)"
        exit 1
    }
}

Switch ($type) {
    "create" { create }
    "read" { read }
    "update" { update }
    "delete" { delete }
}