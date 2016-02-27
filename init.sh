#!/bin/sh 
DEMO="Loan Realtime Decision Server Demo"
AUTHORS="Edson Tirelli, Eric D. Schabell"
PROJECT1="git@github.com:"
PROJECT2="jbossdemocentral/brms-realtime-decision-server-demo.git"
PRODUCT="JBoss BRMS"
JBOSS_HOME=./target/jboss-eap-6.4
SERVER_DIR=$JBOSS_HOME/standalone/deployments
SERVER_CONF=$JBOSS_HOME/standalone/configuration
SERVER_BIN=$JBOSS_HOME/bin
SUPPORT_DIR=./support
SRC_DIR=./installs
PRJ_DIR=./projects
BRMS=jboss-brms-6.2.0.GA-installer.jar
EAP=jboss-eap-6.4.0-installer.jar
EAP_PATCH=jboss-eap-6.4.6-patch.zip
VERSION=6.2

# wipe screen.
clear 

echo
echo "##############################################################################"
echo "##                                                                          ##"   
echo "##  Setting up the ${DEMO}                       ##"
echo "##                                                                          ##"   
echo "##                                                                          ##"   
echo "##    ##### ####   ###   ####  ####    ####   ####    #   #    ####         ##"
echo "##      #   #   # #   # #     #        #   #  #   #  # # # #  #             ##"
echo "##      #   ####  #   #  ###   ###     ####   ####   #  #  #   ###          ##"
echo "##    # #   #   # #   #     #     #    #   #  #  #   #     #      #         ##"
echo "##    ###   ####   ###  ####  ####     ####   #   #  #     #  ####          ##"
echo "##                                                                          ##"   
echo "##                                                                          ##"   
echo "##  brought to you by ${AUTHORS}                       ##"
echo "##                                                                          ##"   
echo "##  ${PROJECT1}                                                         ##"
echo "##   ${PROJECT2}                ##"
echo "##                                                                          ##"   
echo "##############################################################################"
echo

command -v mvn -q >/dev/null 2>&1 || { echo >&2 "Maven is required but not installed yet... aborting."; exit 1; }

# make some checks first before proceeding.	
if [ -r $SRC_DIR/$EAP ] || [ -L $SRC_DIR/$EAP ]; then
	echo JBoss EAP sources are present...
	echo
else
	echo Need to download $EAP package from the Customer Portal 
	echo and place it in the $SRC_DIR directory to proceed...
	echo
	exit
fi

if [ -r $SRC_DIR/$EAP_PATCH ] || [ -L $SRC_DIR/$EAP_PATCH ]; then
	echo Product patches are present...
	echo
else
	echo Need to download $EAP_PATCH package from the Customer Portal 
	echo and place it in the $SRC_DIR directory to proceed...
	echo
	exit
fi

if [ -r $SRC_DIR/$BRMS ] || [ -L $SRC_DIR/$BRMS ]; then
	echo JBoss BRMS sources are present...
	echo
else
	echo Need to download $BRMS package from the Customer Portal 
	echo and place it in the $SRC_DIR directory to proceed...
	echo
	exit
fi

# Remove the old JBoss instance, if it exists.
if [ -x $JBOSS_HOME ]; then
	echo "  - existing JBoss product install detected and removed..."
	echo
	rm -rf ./target
fi

# Run installers.
echo "JBoss EAP installer running now..."
echo
java -jar $SRC_DIR/$EAP $SUPPORT_DIR/installation-eap -variablefile $SUPPORT_DIR/installation-eap.variables

if [ $? -ne 0 ]; then
	echo
	echo Error occurred during JBoss EAP installation!
	exit
fi

echo
echo "Applying JBoss EAP 6.4.6 patch now..."
echo
$JBOSS_HOME/bin/jboss-cli.sh --command="patch apply $SRC_DIR/$EAP_PATCH"

if [ $? -ne 0 ]; then
	echo
	echo Error occurred during JBoss EAP patching!
	exit
fi

echo
echo "JBoss BRMS installer running now..."
echo
java -jar $SRC_DIR/$BRMS $SUPPORT_DIR/installation-brms -variablefile $SUPPORT_DIR/installation-brms.variables

if [ $? -ne 0 ]; then
	echo Error occurred during $PRODUCT installation!
	exit
fi


echo
echo "  - creating kie-server user..."
echo
$JBOSS_HOME/bin/add-user.sh -a -r ApplicationRealm -u kieserver -p kieserver1! -ro kie-server --silent
$JBOSS_HOME/bin/add-user.sh -a -r ApplicationRealm -u demo1 -p jbossbrms1! -ro admin --silent
$JBOSS_HOME/bin/add-user.sh -a -r ApplicationRealm -u demo2 -p jbossbrms1! -ro admin --silent
$JBOSS_HOME/bin/add-user.sh -a -r ApplicationRealm -u demo3 -p jbossbrms1! -ro admin --silent
$JBOSS_HOME/bin/add-user.sh -a -r ApplicationRealm -u demo4 -p jbossbrms1! -ro admin --silent
$JBOSS_HOME/bin/add-user.sh -a -r ApplicationRealm -u demo5 -p jbossbrms1! -ro admin --silent

echo "  - enabling demo accounts role setup in application-roles.properties file..."
echo
cp $SUPPORT_DIR/application-roles.properties $SERVER_CONF

echo "  - setting up demo projects..."
echo
cp -r $SUPPORT_DIR/brms-demo-niogit $SERVER_BIN/.niogit

echo "  - setting up standalone.xml configuration adjustments..."
echo
cp $SUPPORT_DIR/standalone.xml $SERVER_CONF

echo "  - setup email notification users..."
echo
cp $SUPPORT_DIR/userinfo.properties $SERVER_DIR/business-central.war/WEB-INF/classes/

echo "  - making sure standalone.sh for server is executable..."
echo
chmod u+x $JBOSS_HOME/bin/standalone.sh

echo "You can now start the ${PRODUCT} with ${SERVER_BIN}/standalone.sh"
echo

echo "${PRODUCT} ${VERSION} ${DEMO} Setup Complete."
echo

