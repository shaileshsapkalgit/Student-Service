# ===========================================
# Stage 1: BUILD
# ===========================================
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder

WORKDIR /app

# Cache optimization - pehle pom.xml
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Source code copy
COPY src ./src

# Build jar
RUN mvn clean package -DskipTests -B

# ===========================================
# Stage 2: RUNTIME
# ===========================================
FROM eclipse-temurin:17-jre-alpine AS runtime

# Non-root user - security best practice
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Sirf jar copy karo builder se
COPY --from=builder /app/target/*.jar app.jar

RUN chown appuser:appgroup app.jar

USER appuser

EXPOSE 8081

# Health check for Kubernetes
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8081/actuator/health || exit 1

# JVM container-aware settings
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]