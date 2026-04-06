# Stack-Specific Patterns

## Node.js / TypeScript

| Concern          | Tool / Config                                              |
|------------------|------------------------------------------------------------|
| Package manager  | Use what the spec says. Default to `pnpm` if unspecified.  |
| Linter           | ESLint with flat config (`eslint.config.js`). Include      |
|                  | `@typescript-eslint/parser` and                            |
|                  | `@typescript-eslint/eslint-plugin`.                        |
| Formatter        | Prettier with minimal config (printWidth, semi,            |
|                  | singleQuote).                                              |
| Type checker     | `tsc --noEmit` (strict mode enabled).                      |
| Test runner      | Vitest (default) or Jest if specified. Configure coverage   |
|                  | with `v8` provider.                                        |
| Build            | `tsc` for libraries, bundler (esbuild/vite) for apps.     |
| Telemetry        | `@opentelemetry/sdk-node`,                                 |
|                  | `@opentelemetry/auto-instrumentations-node`.               |
| Dockerfile       | Node 22 alpine base, multi-stage with `pnpm deploy --prod` |
|                  | or equivalent for minimal production image.                |

## Python

| Concern          | Tool / Config                                              |
|------------------|------------------------------------------------------------|
| Package manager  | `uv` (default) or `pip` if specified. Generate             |
|                  | `pyproject.toml` with project metadata and dependencies.   |
| Linter/formatter | `ruff` for both. Configure via `[tool.ruff]` in            |
|                  | `pyproject.toml`.                                          |
| Type checker     | `pyright` (default for stricter defaults) or `mypy`.       |
| Test runner      | `pytest` with `pytest-cov` for coverage.                   |
| Build            | `uv build` for packages, direct execution for apps.       |
| Telemetry        | `opentelemetry-sdk`, `opentelemetry-instrumentation` with  |
|                  | auto-instrumentation for frameworks (FastAPI, Flask,       |
|                  | Django).                                                   |
| Dockerfile       | Python 3.12 slim base, multi-stage with `uv pip install`  |
|                  | in builder and copy of virtualenv to runtime.              |

## Rust

| Concern          | Tool / Config                                              |
|------------------|------------------------------------------------------------|
| Package manager  | `cargo` (standard). Use workspace layout if the spec has   |
|                  | multiple domains.                                          |
| Linter           | `clippy` with `-- -D warnings` to treat warnings as       |
|                  | errors.                                                    |
| Formatter        | `rustfmt` with default settings.                           |
| Test runner      | `cargo test`. Use `cargo-llvm-cov` for coverage if         |
|                  | specified.                                                 |
| Build            | `cargo build --release`. Use workspace members for         |
|                  | multi-crate projects.                                      |
| Telemetry        | `tracing` crate with `tracing-opentelemetry` bridge and    |
|                  | `opentelemetry-otlp` exporter.                             |
| Dockerfile       | `rust:1.82-slim` builder, `debian:bookworm-slim` runtime.  |
|                  | Statically link with `musl` for alpine if binary size is   |
|                  | a concern.                                                 |

## Go

| Concern          | Tool / Config                                              |
|------------------|------------------------------------------------------------|
| Package manager  | Go modules (`go mod init`). Generate `go.mod` with correct |
|                  | module path.                                               |
| Linter           | `golangci-lint` with `.golangci.yml` enabling `govet`,     |
|                  | `staticcheck`, `errcheck`, `gosec`, `unused` at minimum.   |
| Formatter        | `gofmt` (standard, no configuration needed).               |
| Test runner      | `go test ./...` with `-race` flag. Use `-coverprofile`     |
|                  | for coverage.                                              |
| Build            | `go build -o bin/` with appropriate `ldflags` for version  |
|                  | embedding.                                                 |
| Telemetry        | `go.opentelemetry.io/otel` SDK with `otlptracehttp`       |
|                  | exporter and `otelhttp` middleware for HTTP servers.        |
| Dockerfile       | `golang:1.23-alpine` builder, `alpine:3.20` runtime.      |
|                  | Build with `CGO_ENABLED=0` for static binary.             |

## Other Stacks

For stacks not listed above, adapt by following the same pattern: identify the canonical
package manager, linter, formatter, type checker (if applicable), test runner, and build
tool. Use the most widely adopted tooling for that ecosystem.
