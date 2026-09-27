*** Settings ***
Documentation     Configuring collective.webhook to broadcast a BPMN signal
...               to Operaton (Camunda 7): a content rule POSTs to
...               engine-rest's /signal endpoint whenever content is
...               published, broadcasting a signal named "plone" that
...               docs/src/diagrams/ping.bpmn's signal start event (also
...               named "plone") starts a fresh instance from -- unlike a
...               message, a signal reaches every waiting instance, so this
...               starts a new one each time rather than correlating to one
...               that already exists.
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
${PAYLOAD}        {"name": "plone", "variables": {"contentUrl": {"value": "\${url}", "type": "String"}, "contentTitle": {"value": "\${title}", "type": "String"}, "uuid": {"value": "\${uid}", "type": "String"}}}


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
    ...    signal-started instance exists, so its recording spans both the
    ...    rule's configuration and the moment the new instance appears.
    ${state}=    Log In To Cockpit
    Start Observer    cockpit    ${COCKPIT_URL}/    storage_state=${state}

Administrator Configures The Webhook Rule
    [Documentation]    Webhook + Operaton signal · 1 / 2. Site Setup >
    ...    Content Rules: a "Call webhook" action broadcasts a BPMN signal to
    ...    Operaton whenever content is published -- scoped with Plone's own
    ...    "Workflow transition" condition, or "Object modified" (which
    ...    "Workflow state changed" also is) would fire it on every edit too.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Webhook + Operaton signal · 1 / 2
    ...    title=Administrator    subtitle=Configuring the webhook content rule
    Add Webhook Content Rule
    ...    Signal Operaton on publish
    ...    Workflow state changed
    ...    ${ENGINE_URL}/signal
    ...    ${PAYLOAD}
    ...    POST
    ...    Publish
    Take Screenshot    ${SHOTS_DIR}/webhook-signal-rule-applied.png
    [Teardown]    End Actor Turn

Administrator Publishes A Document
    [Documentation]    Webhook + Operaton signal · 2 / 2. Publishing the
    ...    document fires the rule: once Plone's transaction commits, it
    ...    POSTs to Operaton, which broadcasts the "plone" signal and starts
    ...    a fresh Demo instance from its signal start event.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Webhook + Operaton signal · 2 / 2
    ...    title=Administrator    subtitle=Publishing content to trigger the webhook
    Go To    ${BASE_URL}
    Add Content    Document    ${DOC_TITLE}
    Publish Current Document
    Take Screenshot    ${SHOTS_DIR}/webhook-signal-document-published.png
    [Teardown]    End Actor Turn

Wrap Up In Cockpit
    [Documentation]    The signal-started instance appears in Cockpit
    ...    without this story reaching back into it: the webhook call, not
    ...    this recording, is what created it.
    Wait For Process Instance In Cockpit    Demo
    Take Screenshot    ${SHOTS_DIR}/webhook-signal-cockpit-instance.png
    End Observer
