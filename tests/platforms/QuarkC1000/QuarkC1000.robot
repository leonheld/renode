*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Resource                      ${CURDIR}/../../../src/Renode/RobotFrameworkEngine/renode-keywords.robot
Library                       quark_helper.py

*** Variables ***
${CPU}                        sysbus.cpu
${UART}                       sysbus.uart_b
${URI}                        @http://antmicro.com/projects/renode
${SCRIPT}                     ${CURDIR}/../../../src/Emul8/scripts/demos/standalone/quark_c1000-shell

*** Test Cases ***
Should Run Hello World
    [Documentation]           Runs Zephyr's 'hello_world' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart
    Execute Command           $bin = ${URI}/hello_world.elf-s_314404-767e7a65942935de2abf276086957170847d99b5
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation
    Wait For Line On Uart     Hello World! x86

Should Run Hello World With Sleep
    [Documentation]           Runs modified Zephyr's 'hello_world' sample on Quark C1000 platform. This one outputs 'Hello World! x86' on uart every 2 seconds.
    [Tags]                    zephyr  uart  interrupts
    Set Test Variable         ${SLEEP_TIME}                 2000
    Set Test Variable         ${SLEEP_TOLERANCE}            20
    Set Test Variable         ${REPEATS}                    10

    Execute Command           $bin = ${URI}/hello_world-with-sleep.elf-s_317148-a279de34d55b10c97720845fdf7e58bd42bb0477
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation

    ${l}=               Create List
    ${MAX_SLEEP_TIME}=  Evaluate  ${SLEEP_TIME} + ${SLEEP_TOLERANCE}

    :FOR  ${i}  IN RANGE  0  ${REPEATS}
    \              Wait For Line On Uart     Hello World! x86
    \     ${t}=    Get Virtual Timestamp Of Last Event
    \              Append To List            ${l}  ${t}

    :FOR  ${i}  IN RANGE  1  ${REPEATS}
    \     ${i1}=  Get From List   ${l}                       ${i - 1}
    \     ${i2}=  Get From List   ${l}                       ${i}
    \     ${d}=   Evaluate        ${i2} - ${i1}
    \             Should Be True  ${d} >= ${SLEEP_TIME}      Too short sleep detected between entries ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}
    \             Should Be True  ${d} <= ${MAX_SLEEP_TIME}  Too long sleep detected between entires ${i} and ${i + 1}: expected ${SLEEP_TIME}, got ${d}

Should Run Shell
    [Documentation]           Runs Zephyr's 'shell' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart  interrupts
    Execute Command           $bin = ${URI}/shell.elf-s_392956-4b5bdd435f3d7c6555e78447438643269a87186b
    Execute Script            ${SCRIPT}
# Explicit creation of the sync domain here is kind of a hack and should be removed after #8011 is resolved.
    Execute Command           emulation AddSyncDomain
    Execute Command           machine SetSyncDomainFromEmulation 0

    Create Terminal Tester    ${UART}  shell>
    Start Emulation

    Wait For Prompt On Uart
    Set New Prompt For Uart   sample_module>
    Write Line To Uart        select sample_module
    Wait For Prompt On Uart
    Write Line To Uart        ping
    Wait For Line On Uart     pong

Should Handle Gpio Button
    [Documentation]           Runs Zephyr's 'basic/button' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart  interrupts  gpio  button  non-critical
    Set Test Variable         ${WAIT_PERIOD}             5
    Execute Command           $bin = ${URI}/button.elf-s_317524-b42765dd760d0dd260079b99724aabec2b5cf34b
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     Press the user defined button on the board
    Test If Uart Is Idle      ${WAIT_PERIOD}
    Execute Command           gpio.button Toggle
    Test If Uart Is Idle      ${WAIT_PERIOD}
    Execute Command           gpio.button Toggle
    Wait For Line On Uart     Button pressed
    Test If Uart Is Idle      ${WAIT_PERIOD}
    Execute Command           gpio.button PressAndRelease
    Wait For Line On Uart     Button pressed

Should Read Sensor
    [Documentation]           Runs antmicro's 'sensor/lm74' sample on Quark C1000 platform.
    [Tags]                    zephyr  uart  lm74  temperature  sensor  spi
    Set Test Variable         ${SENSOR}             spi0.lm74

    Execute Command           $bin = ${URI}/lm74.elf-s_397752-47a08286be251887f15b378bd3c9f0d7829e1469
    Execute Script            ${SCRIPT}

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     SPI Example application
    Wait For Line On Uart     Current temperature: 0.0
    Execute Command           ${SENSOR} Temperature 36
    Wait For Line On Uart     Current temperature: 36.0

Should Talk Over Network Using Ethernet
    [Documentation]           Runs Zephyr's 'net/echo' sample on Quark C1000 platform with external ENC28J60 ethernet module.
    [Tags]                    zephyr  uart  spi  ethernet  gpio
    Set Test Variable         ${REPEATS}             10

    Execute Command           emulation CreateSwitch "switch"
    Execute Command           emulation AddSyncDomain
    Execute Command           switch SetSyncDomainFromEmulation 0
    Execute Command           $bin = ${URI}/echo_server.elf-s_684004-1ebf8c5dffefb95db60350692cf81fb7fd888869
    Execute Script            ${SCRIPT}
    Execute Command           machine SetSyncDomainFromEmulation 0
    Execute Command           connector Connect spi1.ethernet switch

    Execute Command           mach clear
    Execute Command           $bin = ${URI}/echo_client.elf-s_686384-fab5f2579652cf4bf16d68a456e6f6e4dbefbafa
    Execute Script            ${SCRIPT}
    Execute Command           machine SetSyncDomainFromEmulation 0
    Execute Command           connector Connect spi1.ethernet switch
    Create Terminal Tester    ${UART}  machine=machine-1

    Start Emulation

    :FOR  ${i}  IN RANGE  1  ${REPEATS}
    \    ${r}=  Evaluate  random.randint(1, 50)  modules=random
    \    RepeatKeyword  ${r}  
    \    ...  Wait For Next Line On Uart
    \
    \    ${p}=  Wait For Line On Uart     udp_sent: IPv4: sent
    \    ${n}=  Wait For Next Line On Uart
    \
    \    ${m}=  Get Regexp Matches  ${p}  \\d+
    \    Should Contain  ${n}  Compared ${m[1]} bytes, all ok

Should Serve Webpage Using Tap
    [Documentation]           Runs Zephyr's 'net/http' sample on Quark C1000 platform with external ENC28J60 ethernet module.
    [Tags]                    zephyr  uart  spi  ethernet  gpio  tap
    Set Test Variable         ${TAP_INTERFACE}     tap0
    Set Test Variable         ${TAP_INTERFACE_IP}  192.0.2.1
    Set Test Variable         ${SERVER_IP}         192.0.2.2
    Set Test Variable         ${SERVER_PORT}       80

    Network Interface Should Have Address  ${TAP_INTERFACE}  ${TAP_INTERFACE_IP}

    Execute Command           emulation CreateSwitch "switch"
    Execute Command           emulation AddSyncDomain
    Execute Command           switch SetSyncDomainFromEmulation 0

    Execute Command           emulation CreateTap "tap0" "tap"
    Execute Command           connector Connect host.tap switch

    Execute Command           $bin = ${URI}/http_server.elf-s_831660-df4e7a424882a5eb4883dddb3988971760732f78
    Execute Script            ${SCRIPT}
    Execute Command           machine SetSyncDomainFromEmulation 0
    Execute Command           connector Connect spi1.ethernet switch
    Create Terminal Tester    ${UART}

    Start Emulation

    Wait For Line On Uart     Address: ${SERVER_IP}, port: ${SERVER_PORT}
    ${resp}=                  Get Request  http://${SERVER_IP}:${SERVER_PORT}/index.html
    Should Contain            ${resp.text}  It Works!
    Should Contain            ${resp.text}  Temperature: 0.000