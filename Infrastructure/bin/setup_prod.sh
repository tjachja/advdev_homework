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

create_app() {
    local app_name=$1
    local app_display_name=$2
    local image=$3
    local type_label=$4

    ${ocp} new-app ${image} --allow-missing-images=true --allow-missing-imagestream-tags=true --name=${app_name} -l type=${type_label}

    ${ocp} set triggers dc/${app_name} --remove-all
    ${ocp} rollout cancel dc/${app_name}

    ${ocp} expose dc/${app_name} --port 8080

    ${ocp} set probe dc/${app_name} --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
    ${ocp} set probe dc/${app_name} --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/

    ${ocp} create configmap ${app_name}-config --from-literal=APPNAME="${app_display_name}"
    ${ocp} set env dc/${app_name} --from=configmap/${app_name}-config
}

create_parks_backend() {
    local app_name=$1
    local app_display_name=$2
    local image=$3
    local type_label=$4
    
    echo "creating ${app_display_name} backend app"

    create_app ${app_name} "${app_display_name}" ${image} ${type_label}
    ${ocp} create configmap parksdb-config --from-literal=DB_HOST=mongodb --from-literal=DB_PORT=27017 --from-literal=DB_USERNAME=mongodb --from-literal=DB_PASSWORD=mongodb --from-literal=DB_NAME=parks
    
    ${ocp} set env dc/${app_name} --from=configmap/parksdb-config

    ${ocp} set deployment-hook dc/${app_name} --post -- curl -s http://${app_name}:8080/ws/data/load/
}

# Create mongodb app
echo "Creating mongodb"

oc new-app -f ../templates/mongo.yaml -n ${GUID}-parks-prod --env=REPLICAS=3 

create_parks_backend "mlbparks-blue"  "MLB Parks (Blue)"  "${GUID}-parks-dev/mlbparks:0.0" "parksmap-backend-standby"
create_parks_backend "mlbparks-green" "MLB Parks (Green)" "${GUID}-parks-dev/mlbparks:0.0" "parksmap-backend"

create_parks_backend "nationalparks-blue" "National Parks (Blue)" "${GUID}-parks-dev/nationalparks:0.0" "parksmap-backend-standby"
create_parks_backend "nationalparks-green" "National Parks (Green)" "${GUID}-parks-dev/nationalparks:0.0" "parksmap-backend"

oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-prod

create_app "parksmap-blue"  "ParksMap (Blue)"   "${GUID}-parks-dev/parksmap:0.0" "parksmap-frontend-standby"
create_app "parksmap-green" "ParksMap (Green)"  "${GUID}-parks-dev/parksmap:0.0" "parksmap-frontend"

${ocp} expose svc/parksmap-green --name parksmap
