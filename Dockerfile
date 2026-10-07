# Stage 1: Build application with Maven
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /workspace

# Copy maven executable and dependency descriptors first for layer caching
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw mvnw

# Resolve dependencies offline
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copy application source code and build
COPY src src
RUN ./mvnw clean package -DskipTests

# Stage 2: Runtime image with minimal JRE
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Create non-root system user for security
RUN addgroup -S cloudnotes && adduser -S cloudnotes -G cloudnotes
USER cloudnotes

# Copy built JAR from builder stage
COPY --from=builder /workspace/target/*.jar app.jar

# Expose standard application port
EXPOSE 8080

# Configure container healthcheck using Actuator endpoint
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
