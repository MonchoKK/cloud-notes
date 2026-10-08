# ==============================================================================
# CloudNotes - Multi-Stage Containerfile
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build Application Artifact with Maven
# ------------------------------------------------------------------------------
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /workspace

# Copy build descriptors and wrapper first to leverage Docker layer caching
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw mvnw

# Ensure execution bit is set on Maven wrapper and download dependencies
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copy source tree and compile/package the executable Spring Boot JAR
COPY src src
RUN ./mvnw clean package -DskipTests -B

# ------------------------------------------------------------------------------
# Stage 2: Minimal Distroless/Alpine JRE Runtime Image
# ------------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine

LABEL org.opencontainers.image.title="CloudNotes" \
      org.opencontainers.image.description="Cloud-native notes service powered by Spring Boot 3 & Java 21" \
      org.opencontainers.image.vendor="CloudNotes"

WORKDIR /app

# Create unprivileged system group and user for security compliance (non-root)
RUN addgroup -g 1001 -S cloudnotes && \
    adduser -u 1001 -S cloudnotes -G cloudnotes

# Set up default containerized JVM flags:
# - UseContainerSupport: Auto-detect CPU shares and cgroup memory limits
# - MaxRAMPercentage: Prevent out-of-memory container kills by sizing heap proportionally
# - Djava.security.egd: Non-blocking entropy source for fast cryptographic initialization
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom" \
    PORT=8080

# Copy only the final repackaged Spring Boot executable JAR with correct ownership
COPY --from=builder --chown=cloudnotes:cloudnotes /workspace/target/cloud-notes-*.jar app.jar

# Switch to unprivileged runtime user
USER cloudnotes:cloudnotes

# Expose HTTP application service port
EXPOSE 8080

# Actuator-driven container health probe
# start-period gives Spring Boot adequate warm-up time before failing probes
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Launch Spring Boot with exec so the JVM process runs as PID 1 to capture SIGTERM/SIGINT signals
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar \"$@\"", "--"]
