## Build stage
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /workspace

# The agentic subprocess plugins cannot be resolved from the snapshot repository as normal
# dependencies (their parent POM is not published), so install them first.
COPY fluxnova-service/install-agentic-plugins.sh ./install-agentic-plugins.sh
RUN sh ./install-agentic-plugins.sh

COPY fluxnova-service/pom.xml ./fluxnova-service/pom.xml
RUN mvn -q -f fluxnova-service/pom.xml dependency:go-offline

COPY fluxnova-service ./fluxnova-service
RUN mvn -q -f fluxnova-service/pom.xml clean package -DskipTests

## Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S fluxnova && adduser -S fluxnova -G fluxnova
RUN mkdir -p /data/h2 && chown -R fluxnova:fluxnova /data

USER fluxnova

COPY --from=builder /workspace/fluxnova-service/target/*.jar app.jar

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=5 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

VOLUME ["/data/h2"]

ENTRYPOINT ["java", "-jar", "app.jar"]
