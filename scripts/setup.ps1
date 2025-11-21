start powerpnt.exe docs/L360OR25-PermitToCloud.pptx

dotnet new webapp -o src/myApp --framework net8.0
dotnet new sln -n wgc25
dotnet sln add src/myApp
devenv wgc25.sln
