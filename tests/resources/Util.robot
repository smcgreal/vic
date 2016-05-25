*** Settings ***
Library  OperatingSystem
Library  String
Library  Collections
Library  requests

*** Variables ***
${esxi}  192.168.254.128
${install}  vic-machine -target=${esxi} -user=root -image-store=datastore1 -appliance-iso=/src/github.com/vmware/vic/bin/appliance.iso -bootstrap-iso=/src/github.com/vmware/vic/bin/bootstrap.iso -generate-cert=true -passwd=vmware1 -force=true -bridge-network=network -compute-resource=/ha-datacenter/host/localhost.localdomain/Resources

*** Keywords ***
Install VIC Appliance To ESXi Server
    ${status}  ${message} =  Run Keyword And Ignore Error  Variable Should Exist  ${params}
    Run Keyword If  "${status}" == "FAIL"  Log To Console  \nInstalling VCH to ESXi host...
    ${output}=  Run Keyword If  "${status}" == "FAIL"  Run  ${install}
    ${line}=  Run Keyword If  "${status}" == "FAIL"  Get Line  ${output}  -2
    ${ret}=  Run Keyword If  "${status}" == "FAIL"  Fetch From Right  ${line}  ] docker
    ${ret}=  Run Keyword If  "${status}" == "FAIL"  Remove String  ${ret}  info
    Run Keyword If  "${status}" == "FAIL"  Log  ${ret}
    Run Keyword If  "${status}" == "FAIL"  Set Global Variable  ${params}  ${ret}
    
Get State Of Github Issue
    [Arguments]  ${num}
    ${result} =  get  https://api.github.com/repos/vmware/vic/issues/${num}
    Should Be Equal  ${result.status_code}  ${200}
    ${status} =  Get From Dictionary  ${result.json()}  state
    [Return]  ${status}