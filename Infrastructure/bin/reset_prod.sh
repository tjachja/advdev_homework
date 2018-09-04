#!/bin/bash
# Reset Production Project (initial active services: Blue)
# This sets all services to the Blue service so that any pipeline run will deploy Green
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Resetting Parks Production Environment in project ${GUID}-parks-prod to Green Services"

# Code to reset the parks production environment to make
# all the green services/routes active.
# This script will be called in the grading pipeline
# if the pipeline is executed without setting
# up the whole infrastructure to guarantee a Blue
# rollout followed by a Green rollout.

# To be Implemented by Student
ocp="oc -n ${GUID}-parks-prod"

switch_backend() {
	local app_name=$1
	local standby=$2
	local active=$3
	${ocp} delete svc/${app_name}-${active} && \
		oc expose dc/${app_name}-${active} --port=8080 -l type="parksmap-backend"
	${ocp} delete svc/${app_name}-${standby} && \
		oc expose dc/${app_name}-${standby} --port=8080 -l type="parksmap-backend-standby"

}

switch_frontend() {
	local app_name=$1
	local standby=$2
	local active=$3
	${ocp} patch route/${app_name} -p "{\"spec\":{\"to\":{\"name\":\"${app_name}-${to_active}\"}}}" || \
        echo "not patched"

}

switch_backend	"nationalparks" "blue" "green"
switch_backend	"mlbparks" "blue" "green"
switch_frontend	"parksmap" "blue" "green"
