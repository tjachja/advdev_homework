#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Sonarqube in project $GUID-sonarqube"

# Code to set up the SonarQube project.
# Ideally just calls a template
# oc new-app -f ../templates/sonarqube.yaml --param .....

# To be Implemented by Student
TEMPLATES_ROOT=$(dirname $0)/../templates
oc new-app ${TEMPLATES_ROOT}/sonar.yml -n ${GUID}-sonarqube && \
    oc rollout status dc/$(oc get dc -o jsonpath='{ .items[0].metadata.name }' -n ${GUID}-sonarqube) -w -n ${GUID}-sonarqube