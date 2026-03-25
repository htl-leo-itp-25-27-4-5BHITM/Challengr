# Multi-stage Dockerfile for Quarkus backend
# Build stage
FROM maven:3.9.4-eclipse-temurin-21 AS build
WORKDIR /workspace

# copy pom and sources (keep build cache effective)
COPY pom.xml ./
COPY src ./src

# Build the application (skip tests for faster builds; change if you want tests)
RUN mvn -B package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre
WORKDIR /app

# Copy the assembled quarkus app folder from the build stage
COPY --from=build /workspace/target/quarkus-app /app/quarkus-app

EXPOSE 8080

# Ensure Quarkus listens on all interfaces
CMD ["java", "-jar", "/app/quarkus-app/quarkus-run.jar", "-Dquarkus.http.host=0.0.0.0"]
