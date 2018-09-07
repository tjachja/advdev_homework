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

# Code to set up the Jenkins project to execute the

${ocp} new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true

LIN_NUM=$(($(sed -n '/\[registries.insecure\]/=' /etc/containers/registries.conf) + 1))
sed -i "${LIN_NUM}d" /etc/containers/registries.conf
sed "${LIN_NUM}i registries = \['docker-registry-default.apps.na39.openshift.opentlc.com'\]" /etc/containers/registries.conf

sudo systemctl enable docker
sudo systemctl start docker

mkdir -p $HOME/jenkins-slave-appdev
cd  $HOME/jenkins-slave-appdev

echo "FROM docker.io/openshift/jenkins-slave-maven-centos7:v3.9
USER root
RUN yum -y install skopeo apb && \
    yum clean all
USER 1001" > Dockerfile

sudo docker build . -t docker-registry-default.apps.na39.example.opentlc.com/${GUID}-jenkins/jenkins-slave-maven-appdev:v3.9

skopeo copy --dest-tls-verify=false --dest-creds=$(oc whoami):$(oc whoami -t) docker-daemon:docker-registry-default.apps.${CLUSTER}/${GUID}-jenkins/jenkins-slave-maven-appdev:v3.9 docker://docker-registry-default.apps.${CLUSTER}/${GUID}-jenkins/jenkins-slave-maven-appdev:v3.9

echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "mlbparks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/tjachja/advdev_homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        env:
        - name: GUID
          value: 9e5c
        - name: CLUSTER
          value: na39.openshift.opentlc.com
        jenkinsfilePath: MLBParks/Jenkinsfile
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "nationalparks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/tjachja/advdev_homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        env:
        - name: GUID
          value: 9e5c
        - name: CLUSTER
          value: na39.openshift.opentlc.com
        jenkinsfilePath: Nationalparks/Jenkinsfile
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "parksmap-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/tjachja/advdev_homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        env:
        - name: GUID
          value: 9e5c
        - name: CLUSTER
          value: na39.openshift.opentlc.com
        jenkinsfilePath: ParksMap/Jenkinsfile
kind: List
metadata: []" | ${ocp} create -f -
