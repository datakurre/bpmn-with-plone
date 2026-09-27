*** Settings ***
Documentation     Configuring collective.webhook to start an Operaton
...               (Camunda 7) process instance directly: a content rule
...               POSTs to engine-rest's
...               /process-definition/key/Demo/start endpoint whenever
...               content is added anywhere on the site, starting a fresh
...               instance from docs/src/diagrams/ping.bpmn's plain ("none")
...               start event -- no message or signal involved, the
...               approach docs/src/setup.md's own "Plone" section walks
...               through in prose.
...
...               Built on resources/webhook.resource's `Add Webhook Content
...               Rule` and `Wait For Process Instance In Cockpit` -- see
...               that resource's Documentation for what each does, and this
...               directory's README.md for how the four webhook_*.robot
...               scenarios relate. The payload also sets a `uuid` process
...               variable, from `${uid}` -- `collective.webhook`'s own
...               interpolation token for a content's UUID (not `${uuid}`,
...               which `collective.bpmproxy` registers separately and this
...               playground does not install; see
...               webhook_content_lifecycle.robot's own Documentation) --
...               so webhook_content_lifecycle.robot's boundary events can
...               key off it to react to that same document later being
...               modified or removed.
Library           screencast.Screencast    take_dir=${TAKE_DIR}    record=${RECORD}
Resource          resources/webhook.resource


*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${DOC_TITLE}      Plone Conference 2027 unveiled!
${DOC_PATH}       plone-conference-2027-unveiled
@{DEMO_PATHS}     ${DOC_PATH}
${PAYLOAD}        {"variables": {"contentUrl": {"value": "\${url}", "type": "String"}, "contentTitle": {"value": "\${title}", "type": "String"}, "uuid": {"value": "\${uid}", "type": "String"}}}


*** Tasks ***
Prepare The Take
    [Documentation]    Unrecorded: remove any leftover demo document from a
    ...    previous run of this story -- the content rule itself is left in
    ...    place if one already exists from an earlier take.
    Start Scratch Context    ${BASE_URL}
    ...    http_credentials=${{ {'username': $ADMIN_USER, 'password': $ADMIN_PASSWORD} }}
    Delete Demo Content    ${DEMO_PATHS}    base_url=${BASE_URL}
    End Scratch Context

Start Observing In Cockpit
    [Documentation]    Cockpit watches the Demo process definition before the
    ...    directly-started instance exists, so its recording spans both the
    ...    rule's configuration and the moment the new instance appears.
    ${state}=    Log In To Cockpit
    Start Observer    cockpit    ${COCKPIT_URL}/    storage_state=${state}

Administrator Configures The Webhook Rule
    [Documentation]    Webhook + Operaton process start · 1 / 2. Site Setup >
    ...    Content Rules: a "Call webhook" action starts a new Demo process
    ...    instance in Operaton whenever content is added anywhere on the
    ...    site -- no BPMN message or signal event needed on the process
    ...    side, unlike the message and signal scenarios.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Webhook + Operaton process start · 1 / 2
    ...    title=Administrator    subtitle=Configuring the webhook content rule
    Add Webhook Content Rule
    ...    title=Start a Demo process instance
    ...    event=Object added to this container
    ...    url=${ENGINE_URL}/process-definition/key/Demo/start
    ...    payload=${PAYLOAD}
    Take Screenshot    ${SHOTS_DIR}/webhook-process-start-rule-applied.png
    [Teardown]    End Actor Turn

Administrator Adds A Document
    [Documentation]    Webhook + Operaton process start · 2 / 2. Adding
    ...    content now fires the rule: once Plone's transaction commits, it
    ...    POSTs to Operaton, which starts a fresh Demo instance directly --
    ...    no correlation or broadcast involved.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Webhook + Operaton process start · 2 / 2
    ...    title=Administrator    subtitle=Adding content to trigger the webhook
    Go To    ${BASE_URL}
    Add Content    Document    ${DOC_TITLE}
    Take Screenshot    ${SHOTS_DIR}/webhook-process-start-document-added.png
    [Teardown]    End Actor Turn

Wrap Up In Cockpit
    [Documentation]    The directly-started instance appears in Cockpit
    ...    without this story reaching back into it: the webhook call, not
    ...    this recording, is what created it.
    Wait For Process Instance In Cockpit    Demo
    Take Screenshot    ${SHOTS_DIR}/webhook-process-start-cockpit-instance.png
    End Observer
