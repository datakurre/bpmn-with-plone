*** Settings ***
Documentation     Configuring collective.webhook to correlate a BPMN message
...               to Operaton (Camunda 7): a content rule POSTs to
...               engine-rest's /message endpoint whenever content is added
...               anywhere on the site, correlating the process instance
...               that docs/src/diagrams/ping.bpmn's message start event
...               (named "plone") has already been waiting on since Operaton
...               started -- the same delivery the repository README's own
...               curl example makes by hand.
...
...               Built on resources/webhook.resource's `Add Webhook Content
...               Rule` and `Wait For Process Instance In Cockpit` -- see
...               that resource's Documentation for what each does, and this
...               directory's README.md for how the four webhook_*.robot
...               scenarios relate. The payload also sets a `uuid` process
...               variable from the triggering content's own UUID --
...               webhook_content_lifecycle.robot's boundary events key off
...               it to react to that same document later being modified or
...               removed.
Library           screencast.Screencast    take_dir=${TAKE_DIR}    record=${RECORD}
Resource          resources/webhook.resource


*** Variables ***
${SHOTS_DIR}      ${TAKE_DIR}/screenshots
${DOC_TITLE}      Plone Conference 2027 unveiled!
${DOC_PATH}       plone-conference-2027-unveiled
@{DEMO_PATHS}     ${DOC_PATH}
${PAYLOAD}        {"messageName": "plone", "processVariables": {"contentUrl": {"value": "\${url}", "type": "String"}, "contentTitle": {"value": "\${title}", "type": "String"}, "uuid": {"value": "\${uuid}", "type": "String"}}}


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
    ...    message-correlated instance exists, so its recording spans both
    ...    the rule's configuration and the moment the instance appears.
    ${state}=    Log In To Cockpit
    Start Observer    cockpit    ${COCKPIT_URL}/    storage_state=${state}

Administrator Configures The Webhook Rule
    [Documentation]    Webhook + Operaton message · 1 / 2. Site Setup >
    ...    Content Rules: a "Call webhook" action correlates a BPMN message
    ...    to Operaton whenever content is added anywhere on the site.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Webhook + Operaton message · 1 / 2
    ...    title=Administrator    subtitle=Configuring the webhook content rule
    Add Webhook Content Rule
    ...    title=Notify Operaton of new content
    ...    event=Object added to this container
    ...    url=${ENGINE_URL}/message
    ...    payload=${PAYLOAD}
    Take Screenshot    ${SHOTS_DIR}/webhook-message-rule-applied.png
    [Teardown]    End Actor Turn

Administrator Adds A Document
    [Documentation]    Webhook + Operaton message · 2 / 2. Adding content now
    ...    fires the rule: once Plone's transaction commits, it POSTs to
    ...    Operaton, which correlates the "plone" message to the instance
    ...    that has been waiting on it.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Webhook + Operaton message · 2 / 2
    ...    title=Administrator    subtitle=Adding content to trigger the webhook
    Go To    ${BASE_URL}
    Add Content    Document    ${DOC_TITLE}
    Take Screenshot    ${SHOTS_DIR}/webhook-message-document-added.png
    [Teardown]    End Actor Turn

Wrap Up In Cockpit
    [Documentation]    The correlated instance appears in Cockpit without
    ...    this story reaching back into it: the webhook call, not this
    ...    recording, is what moved it.
    Wait For Process Instance In Cockpit    Demo
    Take Screenshot    ${SHOTS_DIR}/webhook-message-cockpit-instance.png
    End Observer
