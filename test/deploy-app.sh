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

# Get tWAS installation properties
source /datadrive/virtualimage.properties

# Parameters and variables
appPackageLocation=$1
appName=$2
nodeName=$(hostname)Node01
cellName=${nodeName}Cell
serverName=server1

# Prepare script for app deployment
deployAppTemplate=deploy-app.py.template
deployAppScript=deploy-app.py
cp $deployAppTemplate $deployAppScript
sed -i "s#\${APP_PACKAGE_LOCATION}#${appPackageLocation}#g" $deployAppScript
sed -i "s/\${NODE_NAME}/${nodeName}/g" $deployAppScript
sed -i "s/\${CELL_NAME}/${cellName}/g" $deployAppScript
sed -i "s/\${SERVER_NAME}/${serverName}/g" $deployAppScript
sed -i "s/\${APP_NAME}/${appName}/g" $deployAppScript

# Install and start the app
${WAS_BASE_INSTALL_DIRECTORY}/profiles/AppSrv1/bin/wsadmin.sh -lang jython -f $deployAppScript
