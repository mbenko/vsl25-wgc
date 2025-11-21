# WGC 2025 Workshop Setup Script

start powerpnt.exe docs/bnk25-wgc-workshop.pptx

# Create solution and web app project
dotnet new webapp -o src/myApp 
dotnet new sln -n wgc25
dotnet sln add src/myApp
devenv26 wgc25.sln


## Aspire demo

# Demo app
dotnet new aspire-starter --use-redis-cache --output src/myAspireSample
cd src/myAspireSample
dotnet run --project AspireSample.AppHost

# Deploy to Azure
azd init
azd provision
azd deploy
azd up
azd monitor

# Optional
az group delete 
