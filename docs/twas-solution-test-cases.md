<!-- Copyright (c) Microsoft Corporation. -->
<!-- Copyright (c) IBM Corporation. -->

# Test cases for IBM WebSphere Application Server Single Instance offer

To ensure no regressions introduced for any changes added to the IBM WebSphere Application Server Single Instance offer, the following test cases must be successfully executed with the expected results before clicking "Go live" for the offer. 

During the execution of the test cases, please open issues for any unexpected results you observed with the reproducible steps.

## Test case 1: User fails to deploy a single instance with an invalid IBMid

Follow steps below to execute the test case:

1. Open offer in the browser ([live offer link](https://ms.portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2022-01-07-twas-base-single-server2022-01-07-twas-base-single-server) or [preview link](https://ms.portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2022-01-07-twas-base-single-server-preview2022-01-07-twas-base-single-server)).
1. Click "Create".
1. The "Basics" tab should be displayed
   1. Create new resource group.
   1. Provide an invalid IBMid.
   1. Accept the IBM License Agreement.
1. Click "Next: Server configuration" to switch to the next tab.
   1. Set password or SSH public key per authentication type for VM administrator.
   1. Set password for WebSphere administrator.
1. Click "Next: Review + create" to switch to the next tab.
   1. Wait and see if validation passed.
   1. For any validation errors, switch to the related tab and fix errors based on validation messages. Re-visit this tab until validation passed.
1. Click "Create" to kick off the deployment.
1. Wait until the deployment failed. You should see the error details including the following message:
   1. The provided IBMid does not have entitlement to install WebSphere Application Server. Please contact the primary or secondary contacts for your IBM Passport Advantage site to grant you access or follow steps at IBM eCustomer Care (https://ibm.biz/IBMidEntitlement) for further assistance.
1. Expand "Deployment details" > find new created "Microsoft.Network/networkSecurityGroups" resource ended with "-nsg" > click its name > click "TCP" > append ",22" to the value of field "Destination port ranges" > click "Save". Wait until change completes.
1. Switch back to deployment page > make sure "Deployment details" is expanded
   1. For new created "Microsoft.Compute/virtualMachines" resource prefixed with "was" > click its name > copy its "Public IP address" > Open a terminal > ssh with websphere vm administrator user name and password/private key > check that there is nothing in directory "/datadrive".
1. Delete the resource group to free up the resource.

## Test case 2: User can successfully deploy a single instance with an entitled IBMid

Follow steps below to execute the test case:

1. Open offer in the browser ([live offer link](https://ms.portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2022-01-07-twas-base-single-server2022-01-07-twas-base-single-server) or [preview link](https://ms.portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2022-01-07-twas-base-single-server-preview2022-01-07-twas-base-single-server)).
1. Click "Create".
1. The "Basics" tab should be displayed
   1. Create new resource group.
   1. Provide an entitled IBMid.
   1. Accept the IBM License Agreement.
1. Click "Next: Server configuration" to switch to the next tab.
   1. Set password or SSH public key per authentication type for VM administrator.
   1. Set password for WebSphere administrator.
1. Click "Next: Review + create" to switch to the next tab.
   1. Wait and see if validation passed.
   1. For any validation errors, switch to the related tab and fix errors based on validation messages. Re-visit this tab until validation passed.
1. Click "Create" to kick off the deployment.
1. Wait until the deployment successfully completes.
1. Open "Outputs" of the deployment page
   1. Copy value of property "adminSecuredConsole" > Open it in the browser tab > You should see login page of "WebSphere Integrated Solutions Console".
   1. Copy value of property "snoopServletUrl" > Open it in the browser tab > You should see a HTML page rendered by servlet "snoop".
   1. Copy value of property "hitCountServletUrl" > Open it in the browser tab > You should see a HTML page rendered by servlet "hitcount".
1. Sign into "WebSphere Integrated Solutions Console" with the user name and password you specified for the WebSphere administrator before.
1. In the left navigation area, click "Servers" > "Server Types" > "WebSphere application servers"
   1. Check "server1" is listed.
1. Switch to deployment page > click "Overview" > Expand "Deployment details"
   1. For new created resource with type "Microsoft.Compute/virtualMachines" > click its name > click "Restart" to restart VM.
   1. Wait until the VM is restarted.
1. Switch to page of "WebSphere Integrated Solutions Console" > Wait until it’s accessible. Repeat step #10. Note: you need to wait for a while before the WebSphere application server is restarted. Refresh the page to get the status update of the server.
1. Delete the resource group to free up the resource.
