#!/bin/sh

#      Copyright (c) Microsoft Corporation.
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

create_standalone_application_profile() {
    # Open ports by adding iptables rules
    firewall-cmd --zone=public --add-port=9060/tcp --permanent
    firewall-cmd --zone=public --add-port=9080/tcp --permanent
    firewall-cmd --zone=public --add-port=9043/tcp --permanent
    firewall-cmd --zone=public --add-port=9443/tcp --permanent
    firewall-cmd --reload

    profileName=$1
    hostName=$2
    nodeName=$3
    adminUserName=$4
    adminPassword=$5

    echo "$(date): Start to create standalone application profile."
    ${WAS_BASE_INSTALL_DIRECTORY}/bin/manageprofiles.sh -create -profileName ${profileName} -hostName ${hostName} \
        -templatePath ${WAS_BASE_INSTALL_DIRECTORY}/profileTemplates/default -nodeName ${nodeName} \
        -enableAdminSecurity true -adminUserName ${adminUserName} -adminPassword ${adminPassword}
    echo "$(date): Standalone application profile created."
}

add_admin_credentials_to_soap_client_props() {
    profileName=$1
    adminUserName=$2
    adminPassword=$3
    soapClientProps=${WAS_BASE_INSTALL_DIRECTORY}/profiles/${profileName}/properties/soap.client.props

    # Add admin credentials
    sed -i "s/com.ibm.SOAP.securityEnabled=false/com.ibm.SOAP.securityEnabled=true/g" "$soapClientProps"
    sed -i "s/com.ibm.SOAP.loginUserid=/com.ibm.SOAP.loginUserid=${adminUserName}/g" "$soapClientProps"
    sed -i "s/com.ibm.SOAP.loginPassword=/com.ibm.SOAP.loginPassword=${adminPassword}/g" "$soapClientProps"
    
    # Encrypt com.ibm.SOAP.loginPassword
    ${WAS_BASE_INSTALL_DIRECTORY}/profiles/${profileName}/bin/PropFilePasswordEncoder.sh "$soapClientProps" com.ibm.SOAP.loginPassword
}

create_was_service() {
    serverName=$1
    serviceName=${serverName}
    profileName=$2
    profilePath=${WAS_BASE_INSTALL_DIRECTORY}/profiles/${profileName}
    
    # Configure SELinux so systemctl has access on server start/stop script files 
    semanage fcontext -a -t bin_t "${profilePath}/bin(/.*)?"
    restorecon -r -v ${profilePath}/bin

    # Add service
    ${profilePath}/bin/wasservice.sh -add ${serviceName} -serverName ${serverName} -profilePath ${profilePath}
}

# Get tWAS installation properties
source /datadrive/virtualimage.properties

# Check whether the user is entitled or not
while [ ! -f "$WAS_LOG_PATH" ]
do
    sleep 5
done

isDone=false
while [ $isDone = false ]
do
    result=`(tail -n1) <$WAS_LOG_PATH`
    if [[ $result = $ENTITLED ]] || [[ $result = $UNENTITLED ]] || [[ $result = $UNDEFINED ]] || [[ $result = $EVALUATION ]]; then
        isDone=true
    else
        sleep 5
    fi
done

# Remove cloud-init artifacts and logs
cloud-init clean --logs

# Terminate the process for the un-entitled or undefined user
if [ ${result} != $ENTITLED ] && [ ${result} != $EVALUATION ]; then
    if [ ${result} = $UNENTITLED ]; then
        echo "The provided IBMid does not have entitlement to install WebSphere Application Server. Please contact the primary or secondary contacts for your IBM Passport Advantage site to grant you access or follow steps at IBM eCustomer Care (https://ibm.biz/IBMidEntitlement) for further assistance."
    else
        echo "No WebSphere Application Server installation packages were found. This is likely due to a temporary issue with the installation repository. Try again and open an IBM Support issue if the problem persists."
    fi
    exit 1
fi

# Check required parameters
if [ "$3" == "True" ] && [ "${8}" == "" ]; then 
  echo "Usage:"
  echo "  ./install.sh [adminUserName] [adminPassword] True [dbType] [jdbcDSJNDIName] [dsConnectionURL] [databaseUser] [databasePassword]"
  exit 1
elif [ "$3" == "" ]; then 
  echo "Usage:"
  echo "  ./install.sh [adminUserName] [adminPassword] False"
  exit 1
fi
adminUserName=$1
adminPassword=$2
enableDB=$3
dbType=$4
jdbcDSJNDIName=$5
dsConnectionURL=$6
databaseUser=$7
databasePassword=$8

create_standalone_application_profile AppSrv1 $(hostname) $(hostname)Node01 "$adminUserName" "$adminPassword"
add_admin_credentials_to_soap_client_props AppSrv1 "$adminUserName" "$adminPassword"
create_was_service server1 AppSrv1
${WAS_BASE_INSTALL_DIRECTORY}/profiles/AppSrv1/bin/startServer.sh server1

# Configure JDBC provider and data source
if [ "$enableDB" == "True" ]; then
    jdbcDataSourceName=dataSource-$dbType
    ./create-ds.sh ${WAS_BASE_INSTALL_DIRECTORY} AppSrv1 server1 "$dbType" "$jdbcDataSourceName" "$jdbcDSJNDIName" "$dsConnectionURL" "$databaseUser" "$databasePassword"

    # Restart server
    ${WAS_BASE_INSTALL_DIRECTORY}/profiles/AppSrv1/bin/stopServer.sh server1
    ${WAS_BASE_INSTALL_DIRECTORY}/profiles/AppSrv1/bin/startServer.sh server1

    # Test connection for the created data source
    ${WAS_BASE_INSTALL_DIRECTORY}/profiles/AppSrv1/bin/wsadmin.sh -lang jython -c "AdminControl.testConnection(AdminConfig.getid('/DataSource:${jdbcDataSourceName}/'))"
    if [[ $? != 0 ]]; then
        echo "$(date): Test data source connection failed."
        exit 1
    fi
fi
