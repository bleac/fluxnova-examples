#!/usr/bin/env sh
# Installs the Fluxnova agentic subprocess plugin JARs into the local Maven repository.
#
# The plugins are published to the Sonatype snapshot repository, but their parent POM
# (org.finos.fluxnova.bpm:fluxnova-plugins:1.0.0) is not published, so Maven cannot resolve
# them as normal dependencies. This script downloads the JARs and installs them with generated
# POMs; pom.xml then declares the plugins' own dependencies explicitly.
#
#   ./install-agentic-plugins.sh                  # the snapshot build this example was tested with
#   ./install-agentic-plugins.sh latest           # the newest published snapshot
#   ./install-agentic-plugins.sh 1.0.0-20260902.152050-4
set -eu

BUILD="${1:-1.0.0-20260902.152050-4}"
VERSION=1.0.0-SNAPSHOT
REPO=https://central.sonatype.com/repository/maven-snapshots/org/finos/fluxnova/bpm
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

for artifact in \
  fluxnova-engine-plugins-shared \
  fluxnova-engine-plugins-ai-agent-config \
  fluxnova-engine-plugins-ai-agent-tool-context-discovery \
  fluxnova-engine-plugins-ai-agent-llm-connector \
  fluxnova-engine-plugins-ai-agentic-tool-invocation \
  fluxnova-engine-plugins-ai-agent-orchestrator
do
  build="$BUILD"
  if [ "$build" = latest ]; then
    build=$(curl -fsS "$REPO/$artifact/$VERSION/maven-metadata.xml" \
      | sed -n 's:.*<value>\(.*\)</value>.*:\1:p' | head -n 1)
  fi
  echo "Installing $artifact ($build)"
  curl -fsS -o "$WORK_DIR/$artifact.jar" "$REPO/$artifact/$VERSION/$artifact-$build.jar"
  mvn -q install:install-file \
    -Dfile="$WORK_DIR/$artifact.jar" \
    -DgroupId=org.finos.fluxnova.bpm \
    -DartifactId="$artifact" \
    -Dversion="$VERSION" \
    -Dpackaging=jar \
    -DgeneratePom=true
done
