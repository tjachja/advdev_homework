#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student
ocp="oc -n ${GUID}-jenkins "

TEMPLATES_ROOT=$(dirname $0)/../templates

echo "Granting permissions"
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-jenkins
oc policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins -n $GUID-jenkins

${ocp} new-app ${TEMPLATES_ROOT}/jenkins.yml
${ocp} rollout status dc/$(${ocp} get dc -o jsonpath='{ .items[0].metadata.name }') -w 

cat ${TEMPLATES_ROOT}/slavepod.Dockerfile | ${ocp} new-build --name=jenkins-slave-appdev -D - 


oc create -f ${TEMPLATES_ROOT}/mlbparks-pipeline.yaml
oc create -f ./Infrastructure/templates/bc-mlbparks.yaml -n ${GUID}-jenkins
oc cancel-build bc/mlbparks-pipeline -n ${GUID}-jenkins || echo "build not cancelled"
oc set env bc/mlbparks-pipeline GUID="$GUID" CLUSTER="$CLUSTER" -n ${GUID}-jenkins
oc start-build bc/mlbparks-pipeline -n ${GUID}-jenkins

oc create -f ${TEMPLATES_ROOT}/nationalparks-pipeline.yaml
oc cancel-build bc/nationalparks-pipeline -n ${GUID}-jenkins || echo "build not cancelled"
oc set env bc/nationalparks-pipeline GUID="$GUID" CLUSTER="$CLUSTER" -n ${GUID}-jenkins
oc start-build bc/nationalparks-pipeline -n ${GUID}-jenkins

oc create -f ${TEMPLATES_ROOT}/parksmap-pipeline.yaml
oc cancel-build bc/parksmap-pipeline -n ${GUID}-jenkins || echo "build not cancelled"
oc set env buildconfigs/parksmap-pipeline GUID="$GUID" CLUSTER="$CLUSTER" -n ${GUID}-jenkins
oc start-build bc/parksmap-pipeline -n ${GUID}-jenkins