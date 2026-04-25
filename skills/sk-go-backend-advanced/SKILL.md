---
name: sk:go-backend-advanced
description: Echo framework (middleware order, error handling), GORM (associations, transactions, hooks), context propagation, profiling (pprof), benchmarking, structured logging (slog/zap), graceful shutdown.
license: MIT
argument-hint: "[echo|gorm|context|profiling|logging|shutdown] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: backend
  last_updated: "2026-04-25"
---

# Go Backend Advanced Skill

Production Go backends with Echo, GORM, observability, and graceful operations.

## When to Use

- Building REST APIs with Echo framework
- Complex GORM queries with associations and transactions
- Adding structured logging and distributed tracing
- Profiling and benchmarking Go services
- Implementing graceful shutdown and context propagation
- Production-ready middleware chains

## Echo Framework

### Setup & Middleware Order

```go
package main

import (
    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"
)

func main() {
    e := echo.New()
    e.HideBanner = true

    // Order matters: RequestID → Logger → Recover → CORS → Auth → RateLimit
    e.Use(middleware.RequestID())
    e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
        Format: `{"time":"${time_rfc3339}","id":"${id}","method":"${method}","uri":"${uri}","status":${status},"latency":"${latency_human}"}` + "\n",
    }))
    e.Use(middleware.Recover())
    e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
        AllowOrigins: []string{"https://myapp.com"},
        AllowMethods: []string{echo.GET, echo.POST, echo.PUT, echo.DELETE},
    }))
    e.Use(middleware.RateLimiterWithConfig(middleware.RateLimiterConfig{
        Store: middleware.NewRateLimiterMemoryStoreWithConfig(
            middleware.RateLimiterMemoryStoreConfig{Rate: 20, Burst: 40},
        ),
    }))

    // Routes
    api := e.Group("/api/v1")
    api.Use(JWTMiddleware()) // route-specific middleware
    api.GET("/users", listUsers)
    api.POST("/users", createUser)

    e.Logger.Fatal(e.Start(":8080"))
}
```

### Custom Error Handling

```go
// Custom error type
type AppError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Status  int    `json:"-"`
}
func (e *AppError) Error() string { return e.Message }

// Global error handler
e.HTTPErrorHandler = func(err error, c echo.Context) {
    var app_err *AppError
    var he *echo.HTTPError
    var status int
    var body any

    switch {
    case errors.As(err, &app_err):
        status = app_err.Status
        body = app_err
    case errors.As(err, &he):
        status = he.Code
        body = map[string]string{"message": fmt.Sprintf("%v", he.Message)}
    default:
        status = http.StatusInternalServerError
        body = map[string]string{"message": "Internal server error"}
    }

    if !c.Response().Committed {
        c.JSON(status, body)
    }
}

// Handler usage
func getUser(c echo.Context) error {
    id := c.Param("id")
    user, err := userService.Find(c.Request().Context(), id)
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return &AppError{Code: "USER_NOT_FOUND", Message: "User not found", Status: 404}
    }
    if err != nil {
        return err // 500
    }
    return c.JSON(200, user)
}
```

## GORM Advanced

### Associations

```go
type User struct {
    gorm.Model
    Name    string
    Email   string    `gorm:"uniqueIndex"`
    Posts   []Post    `gorm:"foreignKey:AuthorID"`
    Profile *Profile  `gorm:"constraint:OnDelete:CASCADE"`
    Roles   []Role    `gorm:"many2many:user_roles"`
}

// Preload associations
db.Preload("Posts", "published = ?", true).
   Preload("Posts.Comments").
   Preload("Profile").
   First(&user, id)

// Joins (SQL JOIN, not multiple queries)
db.Joins("Profile").
   Joins("LEFT JOIN posts ON posts.author_id = users.id").
   Where("posts.published = ?", true).
   Find(&users)

// Association CRUD
db.Model(&user).Association("Roles").Append(&newRole)
db.Model(&user).Association("Roles").Replace(&roles)
db.Model(&user).Association("Roles").Delete(&role)
count := db.Model(&user).Association("Posts").Count()
```

### Transactions

```go
// Standard transaction
err := db.Transaction(func(tx *gorm.DB) error {
    if err := tx.Create(&order).Error; err != nil {
        return err // auto-rollback
    }
    if err := tx.Model(&product).Update("stock", gorm.Expr("stock - ?", qty)).Error; err != nil {
        return err
    }
    return nil // auto-commit
})

// Manual transaction (for complex flows)
tx := db.Begin()
defer func() {
    if r := recover(); r != nil {
        tx.Rollback()
    }
}()

if err := tx.Error; err != nil { return err }
// ... operations
if err := tx.Commit().Error; err != nil { return err }

// SavePoint
tx.SavePoint("sp1")
// ... risky operation
tx.RollbackTo("sp1")
```

### GORM Hooks

```go
func (u *User) BeforeCreate(tx *gorm.DB) error {
    u.ID = uuid.New()
    hash, err := bcrypt.GenerateFromPassword([]byte(u.Password), 12)
    if err != nil { return err }
    u.Password = string(hash)
    return nil
}

func (u *User) AfterFind(tx *gorm.DB) error {
    u.Password = "" // never return password
    return nil
}

// Hooks: BeforeCreate, AfterCreate, BeforeSave, AfterSave,
//        BeforeUpdate, AfterUpdate, BeforeDelete, AfterDelete, AfterFind
```

## Context Propagation

```go
// Attach values to context
type contextKey string
const (
    ctxUserID    contextKey = "user_id"
    ctxRequestID contextKey = "request_id"
)

// Middleware sets context values
func AuthMiddleware(next echo.HandlerFunc) echo.HandlerFunc {
    return func(c echo.Context) error {
        claims, err := validateJWT(c.Request().Header.Get("Authorization"))
        if err != nil { return echo.ErrUnauthorized }

        ctx := context.WithValue(c.Request().Context(), ctxUserID, claims.UserID)
        c.SetRequest(c.Request().WithContext(ctx))
        return next(c)
    }
}

// Service reads from context
func (s *UserService) GetProfile(ctx context.Context) (*User, error) {
    user_id, ok := ctx.Value(ctxUserID).(string)
    if !ok { return nil, errors.New("missing user_id in context") }

    var user User
    return &user, s.db.WithContext(ctx).First(&user, "id = ?", user_id).Error
}
```

## Structured Logging (slog)

```go
import "log/slog"

// Setup (Go 1.21+)
handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
    AddSource: true,
})
logger := slog.New(handler)
slog.SetDefault(logger)

// Usage
slog.Info("user created", "user_id", user.ID, "email", user.Email)
slog.Error("db error", "error", err, "query", query)

// With context (request scoped)
log := slog.With("request_id", c.Response().Header().Get(echo.HeaderXRequestID))
log.Info("processing request", "method", c.Request().Method)
```

## Profiling with pprof

```go
import _ "net/http/pprof" // registers handlers

// Expose pprof on separate port (never on public port)
go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()

// Commands:
// CPU profile: go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
// Memory:      go tool pprof http://localhost:6060/debug/pprof/heap
// Goroutines:  go tool pprof http://localhost:6060/debug/pprof/goroutine
// Trace:       curl http://localhost:6060/debug/pprof/trace?seconds=5 > trace.out
//              go tool trace trace.out
```

## Benchmarking

```go
func BenchmarkUserLookup(b *testing.B) {
    db := setupTestDB(b)
    b.ResetTimer()
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            var user User
            db.First(&user, 1)
        }
    })
}
// go test -bench=. -benchmem -count=3 -cpuprofile=cpu.prof
```

## Graceful Shutdown

```go
func main() {
    e := echo.New()
    // ... setup routes

    // Start server
    go func() {
        if err := e.Start(":8080"); err != nil && !errors.Is(err, http.ErrServerClosed) {
            e.Logger.Fatal("shutting down the server")
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    // Graceful shutdown with 10s timeout
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    // Close resources
    if err := db.Close(); err != nil { log.Printf("db close: %v", err) }
    if err := e.Shutdown(ctx); err != nil { e.Logger.Fatal(err) }
    log.Println("server stopped")
}
```

## Resources

- Echo: https://echo.labstack.com/docs
- GORM: https://gorm.io/docs
- pprof: https://pkg.go.dev/net/http/pprof
- slog: https://pkg.go.dev/log/slog

## User Interaction (MANDATORY)

When activated, ask:

1. **Focus area:** "Bạn cần help phần nào? (Echo routing/GORM queries/logging/profiling/shutdown)"
2. **Current issue:** "Mô tả vấn đề hoặc feature đang implement"
3. **Scale:** "App có bao nhiêu concurrent requests? Để recommend caching/pooling strategy"

Then provide production-ready Go code with proper error handling.
