start powerpnt.exe docs/bnk25-wgc-workshop.pptx

dotnet new webapp -o src/myApp --framework net8.0
dotnet new sln -n wgc25
dotnet sln add src/myApp
devenv wgc25.sln

## Aspire demo
# One-time
dotnet new install Aspire.ProjectTemplates
dotnet dev-certs https --trust

# Demo app
dotnet new aspire-starter --use-redis-cache --output src/myAspireSample
cd src/myAspireSample
dotnet run --project AspireSample.AppHost

# Deploy to Azure
azd init
azd up

# Optional
azd monitor
az group delete -n <rg-name>
