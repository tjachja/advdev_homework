#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

# To be Implemented by Student

TEMPLATES_ROOT=$(dirname $0)/../templates
oc new-app -f ${TEMPLATES_ROOT}/nexus.yaml -n ${GUID}-nexus 

while : ; do
    echo "Checking if Nexus is Ready..."
    oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
	sleep 10
done
echo "configure now"
chmod +x ./Infrastructure/bin/nexus_configuration.sh
./Infrastructure/bin/nexus_configuration.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus )
oc expose dc nexus3 --port=5000 --name=nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000
oc annotate route nexus3 console.alpha.openshift.io/overview-app-route=true
oc annotate route nexus-registry console.alpha.openshift.io/overview-app-route=false