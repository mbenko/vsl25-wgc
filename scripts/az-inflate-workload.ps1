

$envName = "bnk"
$appName = "learn-iac"
$appName = "azcore"
$locName = "centralus"
$repoName = "learn-azure-iac"

$createDt = (Get-Date).ToString("yyyy-MM-dd")
$appOwner = "Mike"
$createBy = "$env:USERNAME"

# Create SPN for workload
$devGroup = "IMA-$appName-DEV"
$rgName = "rg-$appName-$envName"
$spnName = "spn-$appName-$envName"
# --tags "Environment=$envName" "CreatedBy=$createBy" "CreateDt=$createDt" "Owner=$appOwner" "App=$appName" "Repo=$repoName" "Location=$locName"
$tags = @{
    "Environment" = $envName
    "CreatedBy" = $createBy
    "CreateDt" = $createDt
    "Owner" = $appOwner
    "App" = $appName
    "Repo" = $repoName
    "Location" = $locName
}

$tagString = ($tags.GetEnumerator() | ForEach-Object { "`"$($_.Key)=$($_.Value)`"" }) -join " "

$jsonTags = $tags | ConvertTo-Json

az account set --subscription ""

$subID=$(az account show --query id -o tsv)
$tenantID=$(az account show --query tenantId -o tsv)


## AZURE AAD Group CREATION
az ad group create --display-name $devGroup --mail-nickname $devGroup
$groupID = az ad group show --group $devGroup --query id --output tsv
$userID = az ad user show --id "devdad@benko.com" --query id --output tsv
az ad group member add --group $groupID --member-id $userID

# Check that Security group exists
az ad group list -o table | select-string $devGroup
az ad group member list --group $devGroup -o table

# Create the RG

az group create -n $rgName -l $locName --tags "Environment=$envName" "CreatedBy=$createBy" "CreateDt=$createDt" "Owner=$appOwner" "App=$appName" "Repo=$repoName" "Location=$locName"
az group show -n $rgName --query tags # -o table
az role assignment create --assignee $(az ad group show --group "$devGroup" --query id --output tsv) --role "contributor" --scope /subscriptions/$subID/resourceGroups/$rgName 

## CREATE SPN 
### Scope = RG
$spnSecret = az ad sp create-for-rbac -n $spnName --sdk-auth --scopes /subscriptions/$subID/resourceGroups/$rgName --role owner
### Scope = Subscription
$spnSecret = az ad sp create-for-rbac -n $spnName --sdk-auth --scopes /subscriptions/$subID --role owner

# to refresh credentials...
$spnId = az ad sp list --display-name $spnName --query '[0].appId' --output tsv
$spnSecret =  az ad sp credential reset --id $spnId --query "{subscriptionId: '$subId', clientId: appId, clientSecret: password, tenantId: tenant }" -o json | Out-String

# Update/Set the secret in GitHub and Test that it works
$secretName = $spnName.ToUpper().Replace("-","_")
gh secret set $secretName  --body "$($spnSecret | ConvertTo-Json -Compress)" 
gh workflow run az-login  -f secret-name=$secretName
gh run list --workflow=az-login.yml

## STOP HERE

## GITHUB STUFF

# Add contributors to repo (Permssions: pull, triage, push, maintain, admin)  Admin includes access to secrets
gh api --method=PUT "repos/benkotips/wgc/collaborators/bnkdevdad" -permission=pull

# Remove contributors from repo
gh api --method=DELETE "repos/benkotips/wgc/collaborators/bnkdevdad"


# Take inventory
az ad sp list --query "sort_by([].{AppDisplayName:displayName, AppId:appId, CreateDate:createdDateTime}, &CreateDate)" -o table | sort-object
az ad sp list --display-name $spnName --query "sort_by([].{AppDisplayName:displayName, AppId:appId, CreateDate:createdDateTime}, &CreateDate)" -o table

# to clean up
az group delete -g $rgName
az ad sp delete --display-name $spnName
