#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# To be Implemented by Student
ocp="oc -n ${GUID}-parks-dev"
${ocp} policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins

create_app() {
	local app_name=$1
	local s2i_builder_img=$2
	local type_label=$3

	${ocp} new-build --binary=true --name=${app_name} ${s2i_builder_img}
	${ocp} new-app ${GUID}-parks-dev/${app-name}:0.0-0 --allow-missing-imagestream-tags=true --name=${app_name} -l type=${type_label}
	${ocp} set triggers dc/${app_name} --remove-all
	${ocp} expose dc/${app_name} --port 8080

	# health check
	${ocp} set probe dc/${app_name} --liveness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/
	${ocp} set probe dc/${app_name} --readiness --initial-delay-seconds 30 --failure-threshold 3 --get-url=http://:8080/ws/healthz/

}


# creating mongodb
echo "setting up mongodb"
${ocp} new-app mongodb-persistent --name=mongodb --param=MONGODB_USER=mongodb --param=MONGODB_PASSWORD=mongodb --param=MONGODB_DATABASE=parks

${ocp} rollout status dc/mongodb -w

${ocp} create configmap parksdb-config --from-literal=DB_HOST=mongodb --from-literal=DB_PORT=27017 \
--from-literal=DB_USERNAME=mongodb --from-literal=DB_PASSWORD=mongodb --from-literal=DB_NAME=parks

# creating mlbparks
echo "setting up mlb parks app"

create_app "mlbparks" "jboss-eap70-openshift:1.7" "parksmap-backend"

${ocp} create configmap mlbparks-config --from-literal=APPNAME="MLB Parks (Dev)"

${ocp} set env dc/mlbparks --from=configmap/parksdb-config
${ocp} set env dc/mlbparks --from=configmap/mlbparks-config

${ocp} set deployment-hook dc/mlbparks --post curl -s http://mlbparks:8080/ws/data/load

# creating nationalparks
echo "setting up national parks app"

create_app "nationalparks" "redhat-openjdk18-openshift:1.2" "parksmap-backend"

${ocp} create configmap nationalparks-config --from-literal=APPNAME="National Parks (Dev)"

${ocp} set env dc/nationalparks --from=configmap/parksdb-config
${ocp} set env dc/nationalparks --from=configmap/nationalparks-config

${ocp} set deployment-hook dc/nationalparks --post curl -s http://nationalparks:8080/ws/data/load

# creating parksmap
echo "setting up parksmap app"

${ocp} policy add-role-to-user view --serviceaccount=default
create_app "parksmap" "redhat-openjdk18-openshift:1.2" "parksmap-frontend"

${ocp} create configmap parksmap-config --from-literal=APPNAME="ParksMap (Dev)"

${ocp} set env dc/parksmap --from=configmap/parksmap-config
${ocp} expose svc/parksmap

