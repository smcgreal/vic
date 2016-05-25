*** Settings ***
Documentation  Test 1-2 - Docker Pull
Resource  ../../resources/Util.robot
Test Setup  Install VIC Appliance To ESXi Server

*** Keywords ***
Pull image
    [Arguments]  ${image}
    Log To Console  \nRunning docker pull ${image}...
    ${rc}  ${output}=  Run And Return Rc And Output  docker ${params} pull ${image}
    Log  ${output}
    Should Be Equal As Integers  ${rc}  0
    Should contain  ${output}  Status: Image is up to date for library/${image}:latest

*** Test Cases ***
Pull nginx
    Wait Until Keyword Succeeds  5x  15 seconds  Pull image  nginx

Pull busybox
    Wait Until Keyword Succeeds  5x  15 seconds  Pull image  busybox

Pull ubuntu
    Wait Until Keyword Succeeds  5x  15 seconds  Pull image  ubuntu

Pull non-default tag
    Wait Until Keyword Succeeds  5x  15 seconds  Pull image  ubuntu:14.04
    
Pull an image based on digest
    Wait Until Keyword Succeeds  5x  15 seconds  Pull image  ubuntu@sha256:45b23dee08af5e43a7fea6c4cf9c25ccf269ee113168c19722f87876677c5cb2

Pull an image from non-default repo
    Wait Until Keyword Succeeds  5x  15 seconds  Pull image  myregistry.local:5000/testing/test-image
    
Pull an image with all tags
    Wait Until Keyword Succeeds  5x  15 seconds  Pull image  --all-tags fedora
    
Pull non-existent image
    Run Keyword And Expect Error  Pull image  fakebadimage
    
Pull image from non-existent repo
    Run Keyword And Expect Error  Pull image  fakebadrepo.com:9999/ubuntu