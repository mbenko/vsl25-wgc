# C# Coding Patterns for Azure Cloud Development

📖 [Documentation Index](README.md) | [Table of Contents](toc.md)

---

This document outlines recommended coding patterns and best practices for C# development in Azure cloud environments, with a focus on well-governed cloud principles.

## Table of Contents

- [Dependency Injection](#dependency-injection)
- [Configuration Management](#configuration-management)
- [Asynchronous Programming](#asynchronous-programming)
- [Error Handling and Logging](#error-handling-and-logging)
- [Resource Management](#resource-management)
- [Security Best Practices](#security-best-practices)
- [Azure SDK Usage](#azure-sdk-usage)
- [Testing Patterns](#testing-patterns)

## Dependency Injection

Use dependency injection to promote loose coupling and testability:

```csharp
// Good: Constructor injection
public class StorageService
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly ILogger<StorageService> _logger;

    public StorageService(BlobServiceClient blobServiceClient, ILogger<StorageService> logger)
    {
        _blobServiceClient = blobServiceClient ?? throw new ArgumentNullException(nameof(blobServiceClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<string> UploadFileAsync(string containerName, string fileName, Stream content)
    {
        _logger.LogInformation("Uploading file {FileName} to container {ContainerName}", fileName, containerName);
        var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
        var blobClient = containerClient.GetBlobClient(fileName);
        await blobClient.UploadAsync(content, overwrite: true);
        return blobClient.Uri.ToString();
    }
}

// Register in Startup.cs or Program.cs
services.AddSingleton(x => new BlobServiceClient(connectionString));
services.AddScoped<StorageService>();
```

## Configuration Management

Leverage Azure App Configuration and Key Vault for secure configuration:

```csharp
// Good: Use IConfiguration and Azure App Configuration
public class ServiceConfiguration
{
    private readonly IConfiguration _configuration;

    public ServiceConfiguration(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string GetConnectionString(string name)
    {
        // Supports Azure App Configuration and Key Vault references
        return _configuration.GetConnectionString(name);
    }

    public T GetSection<T>(string sectionName) where T : new()
    {
        var section = new T();
        _configuration.GetSection(sectionName).Bind(section);
        return section;
    }
}

// In Program.cs
builder.Configuration.AddAzureAppConfiguration(options =>
{
    options.Connect(Environment.GetEnvironmentVariable("AZURE_APP_CONFIG_CONNECTION_STRING"))
           .ConfigureKeyVault(kv => kv.SetCredential(new DefaultAzureCredential()));
});
```

## Asynchronous Programming

Use async/await properly to improve scalability:

```csharp
// Good: Async all the way
public async Task<IActionResult> ProcessOrderAsync(Order order)
{
    try
    {
        // Use ConfigureAwait(false) in library code to avoid deadlocks
        var validationResult = await ValidateOrderAsync(order).ConfigureAwait(false);
        
        if (!validationResult.IsValid)
        {
            return BadRequest(validationResult.Errors);
        }

        // Process in parallel when operations are independent
        var saveTask = SaveOrderAsync(order);
        var notifyTask = SendNotificationAsync(order);
        
        await Task.WhenAll(saveTask, notifyTask);
        
        return Ok(order);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error processing order {OrderId}", order.Id);
        throw;
    }
}

// Bad: Blocking async code
public IActionResult ProcessOrder(Order order)
{
    var result = ProcessOrderAsync(order).Result; // Don't do this!
    return result;
}
```

## Error Handling and Logging

Implement structured logging and proper exception handling:

```csharp
// Good: Use structured logging with Application Insights
public class OrderProcessor
{
    private readonly ILogger<OrderProcessor> _logger;

    public OrderProcessor(ILogger<OrderProcessor> logger)
    {
        _logger = logger;
    }

    public async Task ProcessAsync(Order order)
    {
        using (_logger.BeginScope(new Dictionary<string, object>
        {
            ["OrderId"] = order.Id,
            ["CustomerId"] = order.CustomerId
        }))
        {
            try
            {
                _logger.LogInformation("Starting order processing");
                
                await ValidateAndProcessOrderAsync(order);
                
                _logger.LogInformation("Order processed successfully");
            }
            catch (ValidationException ex)
            {
                _logger.LogWarning(ex, "Order validation failed");
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error processing order");
                throw;
            }
        }
    }
}

// Custom exception types for better error handling
public class ValidationException : Exception
{
    public ValidationException(string message) : base(message) { }
}
```

## Resource Management

Properly manage Azure resources and implement IDisposable:

```csharp
// Good: Use using statements and IDisposable
public class DocumentProcessor : IDisposable
{
    private readonly HttpClient _httpClient;
    private bool _disposed = false;

    public DocumentProcessor(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<byte[]> DownloadDocumentAsync(string url)
    {
        using var response = await _httpClient.GetAsync(url);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsByteArrayAsync();
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing)
            {
                // Dispose managed resources
                _httpClient?.Dispose();
            }
            _disposed = true;
        }
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }
}

// Better: Use IHttpClientFactory instead
public class DocumentService
{
    private readonly IHttpClientFactory _httpClientFactory;

    public DocumentService(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    public async Task<byte[]> DownloadAsync(string url)
    {
        var client = _httpClientFactory.CreateClient();
        return await client.GetByteArrayAsync(url);
    }
}
```

## Security Best Practices

Implement security best practices for Azure applications:

```csharp
// Good: Use Managed Identity for authentication
public class SecureAzureService
{
    private readonly SecretClient _secretClient;
    private readonly BlobServiceClient _blobServiceClient;

    public SecureAzureService(IConfiguration configuration)
    {
        var credential = new DefaultAzureCredential();
        
        // Use Managed Identity to access Key Vault
        var keyVaultUrl = configuration["KeyVaultUrl"];
        _secretClient = new SecretClient(new Uri(keyVaultUrl), credential);
        
        // Use Managed Identity for Storage
        var storageUrl = configuration["StorageAccountUrl"];
        _blobServiceClient = new BlobServiceClient(new Uri(storageUrl), credential);
    }

    public async Task<string> GetSecretAsync(string secretName)
    {
        var secret = await _secretClient.GetSecretAsync(secretName);
        return secret.Value.Value;
    }
}

// Good: Input validation and sanitization
public class UserInputValidator
{
    public bool ValidateEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return false;

        try
        {
            var addr = new System.Net.Mail.MailAddress(email);
            return addr.Address == email;
        }
        catch
        {
            return false;
        }
    }

    public string SanitizeInput(string input, int maxLength = 1000)
    {
        if (string.IsNullOrEmpty(input))
            return string.Empty;

        // Remove potentially harmful characters
        input = input.Trim();
        
        // Limit length to prevent DoS
        if (input.Length > maxLength)
            input = input.Substring(0, maxLength);

        return input;
    }
}
```

## Azure SDK Usage

Follow best practices when using Azure SDKs:

```csharp
// Good: Implement retry policies and use SDK features
public class ResilientAzureService
{
    private readonly TableServiceClient _tableServiceClient;
    private readonly ILogger<ResilientAzureService> _logger;

    public ResilientAzureService(IConfiguration configuration, ILogger<ResilientAzureService> logger)
    {
        _logger = logger;
        
        var options = new TableClientOptions
        {
            Retry =
            {
                MaxRetries = 3,
                Delay = TimeSpan.FromSeconds(2),
                MaxDelay = TimeSpan.FromSeconds(10),
                Mode = RetryMode.Exponential
            }
        };

        _tableServiceClient = new TableServiceClient(
            configuration["StorageConnectionString"],
            options
        );
    }

    public async Task<List<T>> QueryEntitiesAsync<T>(string tableName, string filter) 
        where T : class, ITableEntity, new()
    {
        var tableClient = _tableServiceClient.GetTableClient(tableName);
        var entities = new List<T>();

        await foreach (var entity in tableClient.QueryAsync<T>(filter))
        {
            entities.Add(entity);
        }

        return entities;
    }
}

// Good: Use cancellation tokens
public async Task<string> ProcessWithCancellationAsync(string data, CancellationToken cancellationToken)
{
    cancellationToken.ThrowIfCancellationRequested();

    var blobClient = _blobServiceClient.GetBlobContainerClient("data").GetBlobClient("file.txt");
    
    using var stream = new MemoryStream(Encoding.UTF8.GetBytes(data));
    await blobClient.UploadAsync(stream, cancellationToken);
    
    return blobClient.Uri.ToString();
}
```

## Testing Patterns

Write testable code with proper mocking and unit tests:

```csharp
// Good: Interface-based design for testability
public interface IStorageRepository
{
    Task<string> SaveAsync(string content);
    Task<string> GetAsync(string id);
}

public class StorageRepository : IStorageRepository
{
    private readonly BlobContainerClient _containerClient;

    public StorageRepository(BlobServiceClient blobServiceClient, string containerName)
    {
        _containerClient = blobServiceClient.GetBlobContainerClient(containerName);
    }

    public async Task<string> SaveAsync(string content)
    {
        var blobId = Guid.NewGuid().ToString();
        var blobClient = _containerClient.GetBlobClient(blobId);
        
        using var stream = new MemoryStream(Encoding.UTF8.GetBytes(content));
        await blobClient.UploadAsync(stream);
        
        return blobId;
    }

    public async Task<string> GetAsync(string id)
    {
        var blobClient = _containerClient.GetBlobClient(id);
        var response = await blobClient.DownloadContentAsync();
        return response.Value.Content.ToString();
    }
}

// Unit test example
[TestClass]
public class StorageServiceTests
{
    [TestMethod]
    public async Task UploadFileAsync_ShouldLogAndUpload()
    {
        // Arrange
        var mockBlobService = new Mock<BlobServiceClient>();
        var mockLogger = new Mock<ILogger<StorageService>>();
        var service = new StorageService(mockBlobService.Object, mockLogger.Object);

        // Act
        using var stream = new MemoryStream(Encoding.UTF8.GetBytes("test"));
        await service.UploadFileAsync("container", "file.txt", stream);

        // Assert
        mockLogger.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Uploading")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception, string>>()),
            Times.Once);
    }
}
```

## Additional Resources

- [Azure SDK for .NET Documentation](https://docs.microsoft.com/en-us/dotnet/azure/)
- [Azure Architecture Center - Best Practices](https://docs.microsoft.com/en-us/azure/architecture/best-practices/)
- [C# Coding Conventions](https://docs.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/)

---

*This document is part of the Well Governed Cloud 2025 Workshop materials.*

📖 [Documentation Index](README.md) | [Table of Contents](toc.md)
