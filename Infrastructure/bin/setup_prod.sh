#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

# To be Implemented by Student
ocp="oc -n ${GUID}-parks-prod"

echo "Grant permissions"
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-prod

${ocp} create configmap parksdb-config --from-literal=DB_HOST=mongodb --from-literal=DB_PORT=27017 --from-literal=DB_USERNAME=mongodb --from-literal=DB_PASSWORD=mongodb --from-literal=DB_NAME=parks

create_app() {
    local app_name=$1
    local app_display_name=$2
    local image=$3
    local type_label=$4

    ${ocp} new-app ${image} --allow-missing-images=true --allow-missing-imagestream-tags=true --name=${app_name} -l type=${type_label}

    ${ocp} set triggers dc/${app_name} --remove-all
    ${ocp} patch dc/${app_name} -p '{"spec": {"strategy": {"type": "Recreate"}}}'
    ${ocp} rollout cancel dc/${app_name}

    ${ocp} expose dc/${app_name} --port 8080

    ${ocp} create configmap ${app_name}-config --from-literal=APPNAME="${app_display_name}"
    ${ocp} set env dc/${app_name} --from=configmap/${app_name}-config
    ${ocp} set env dc/${app_name} --from=configmap/parksdb-config

    ${ocp} set probe dc/mlbparks-green --liveness --failure-threshold=4 -initial-delay-seconds=35 -- echo ok
    ${ocp} set probe dc/mlbparks-green --readiness --failure-threshold=4 --initial-delay-seconds=60 --get-url="http://:8080/ws/healthz/"
}

# Create mongodb app
echo "Creating mongodb"
TEMPLATES_ROOT=$(dirname $0)/../templates
${ocp} create -f ${TEMPLATES_ROOT}/mongodb-internal.yaml
${ocp} create -f ${TEMPLATES_ROOT}/mongodb-ss.yaml
${ocp} create -f ${TEMPLATES_ROOT}/mongodb-svc.yaml

# Create apps
create_app "mlbparks-blue"  "MLB Parks (Blue)"  "${GUID}-parks-dev/mlbparks:0.0" "mlbparks-blue"
create_app "mlbparks-green" "MLB Parks (Green)" "${GUID}-parks-dev/mlbparks:0.0" "mlbparks-green"

create_app "nationalparks-blue" "National Parks (Blue)" "${GUID}-parks-dev/nationalparks:0.0" "nationalparks-blue"
create_app "nationalparks-green" "National Parks (Green)" "${GUID}-parks-dev/nationalparks:0.0" "nationalparks-green"

create_app "parksmap-blue"  "ParksMap (Blue)"   "${GUID}-parks-dev/parksmap:0.0" "parksmap-blue"
create_app "parksmap-green" "ParksMap (Green)"  "${GUID}-parks-dev/parksmap:0.0" "parksmap-green"

# Expose Services 
${ocp} expose svc/mlbparks-green --name mlbparks 
${ocp} expose svc/nationalparks-green --name nationalparks
${ocp} expose svc/parksmap-green --name parksmap 
# Create Deployment hooks
${ocp} set deployment-hook dc/mlbparks-green --post -- curl -s http://mlbparks:8080/ws/data/load/ 
${ocp} set deployment-hook dc/nationalparks-green --post -- curl -s http://mlbparks:8080/ws/data/load/ 