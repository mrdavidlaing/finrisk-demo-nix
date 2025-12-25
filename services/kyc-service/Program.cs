using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

app.UseCors();
app.UseSwagger();
app.UseSwaggerUI();

// Health check
app.MapGet("/health", () => Results.Ok(new { status = "healthy", service = "kyc-service" }))
    .WithName("Health")
    .WithOpenApi();

// Verify user identity
app.MapPost("/verify", (VerifyRequest request) =>
{
    // Mock KYC verification - check format
    if (string.IsNullOrWhiteSpace(request.UserId))
    {
        return Results.BadRequest(new { error = "UserId is required" });
    }

    if (string.IsNullOrWhiteSpace(request.Email) || !request.Email.Contains("@"))
    {
        return Results.BadRequest(new { error = "Valid email is required" });
    }

    // Mock: all verifications pass
    var response = new VerifyResponse
    {
        UserId = request.UserId,
        Status = "verified",
        VerifiedAt = DateTime.UtcNow,
        Level = "Tier1"
    };

    return Results.Ok(response);
})
.WithName("Verify")
.WithOpenApi();

// Get KYC status
app.MapGet("/status/{userId}", (string userId) =>
{
    var status = new KYCStatus
    {
        UserId = userId,
        Status = "verified",
        Level = "Tier1",
        LastVerified = DateTime.UtcNow.AddDays(-30)
    };

    return Results.Ok(status);
})
.WithName("GetStatus")
.WithOpenApi();

app.Run("http://localhost:8081");

public record VerifyRequest
{
    public string UserId { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string? FullName { get; init; }
}

public record VerifyResponse
{
    public string UserId { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public DateTime VerifiedAt { get; init; }
    public string Level { get; init; } = string.Empty;
}

public record KYCStatus
{
    public string UserId { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public string Level { get; init; } = string.Empty;
    public DateTime LastVerified { get; init; }
}


