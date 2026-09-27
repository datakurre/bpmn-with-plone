*** Settings ***
Documentation     The content-lifecycle pattern: signals plus BPMN boundary
...               events let a running process react not only to what
...               started it, but to a Plone document later being modified
...               or removed -- the pattern
...               collective.bpmproxy's own
...               examples/published-lifecycle/example-published-lifecycle.bpmn
...               and backend/src/collective/bpmproxy/profiles/default/contentrules.xml
...               demonstrate with its higher-level BPM Signal action ("BPMN
...               signal: modified one"/"deleted one"). This story
...               reproduces the same technique with plain
...               collective.webhook.
...
...               docs/src/diagrams/ping.bpmn's "Review page" user task now
...               carries two interrupting boundary signal events, "Content
...               modified" and "Content removed", whose signals are named
...               `demo-content-modified:${uuid}` /
...               `demo-content-deleted:${uuid}` -- an Operaton EL
...               expression evaluated per instance against its own `uuid`
...               process variable, so each instance only reacts to *its
...               own* document even though Operaton's /signal endpoint
...               always broadcasts by name. Three webhook content rules
...               produce that same string from the Plone side: one starts
...               an instance with `uuid` set from the new content's own
...               UUID, and two more signal that instance back whenever the
...               *same* content is later modified or removed --
...               `${uuid}` in the payload is Plone's own interpolation
...               token, resolved before the HTTP call is even made, quite
...               separate from Operaton's own `${uuid}` in the BPMN model,
...               resolved after it arrives; they only need to agree on the
...               value, which they do because both ultimately come from the
...               same Plone content's UUID.
...
...               Built on resources/webhook.resource's `Add Webhook Content
...               Rule`, `Wait For Process Instance In Cockpit` and `Show
...               Completed Instance In Cockpit History` -- see that
...               resource's Documentation for what each does, and this
...               directory's README.md for how the four webhook_*.robot
...               scenarios relate.
Library           screencast.Screencast    take_dir=${TAKE_DIR}    record=${RECORD}
Resource          resources/webhook.resource


*** Variables ***
${SHOTS_DIR}              ${TAKE_DIR}/screenshots
${DOC_TITLE_MODIFIED}     Plone Conference 2027 unveiled!
${DOC_PATH_MODIFIED}      plone-conference-2027-unveiled
${DOC_TITLE_DELETED}      Draft: cancelled sponsor slot
${DOC_PATH_DELETED}       draft-cancelled-sponsor-slot
@{DEMO_PATHS}             ${DOC_PATH_MODIFIED}    ${DOC_PATH_DELETED}
${START_PAYLOAD}          {"variables": {"contentUrl": {"value": "\${url}", "type": "String"}, "uuid": {"value": "\${uuid}", "type": "String"}}}
${MODIFIED_PAYLOAD}       {"name": "demo-content-modified:\${uuid}", "variables": {"contentUrl": {"value": "\${url}", "type": "String"}}}
${DELETED_PAYLOAD}        {"name": "demo-content-deleted:\${uuid}", "variables": {"contentUrl": {"value": "\${url}", "type": "String"}}}


*** Tasks ***
Prepare The Take
    [Documentation]    Unrecorded: remove any leftover demo documents from a
    ...    previous run of this story -- the content rules themselves are
    ...    left in place if they already exist from an earlier take.
    Start Scratch Context    ${BASE_URL}
    ...    http_credentials=${{ {'username': $ADMIN_USER, 'password': $ADMIN_PASSWORD} }}
    Delete Demo Content    ${DEMO_PATHS}    base_url=${BASE_URL}
    End Scratch Context

Start Observing In Cockpit
    [Documentation]    Cockpit watches the Demo process definition before
    ...    either instance exists, so its recording spans configuring the
    ...    rules and both instances later ending through their own boundary
    ...    event.
    ${state}=    Log In To Cockpit
    Start Observer    cockpit    ${COCKPIT_URL}/    storage_state=${state}

Administrator Configures The Webhook Rules
    [Documentation]    Content lifecycle · 1 / 5. Site Setup > Content
    ...    Rules: one rule starts a Demo instance for each new document,
    ...    carrying its UUID as a process variable; two more signal that
    ...    same instance back when the document is later modified or
    ...    removed.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Content lifecycle · 1 / 5
    ...    title=Administrator    subtitle=Configuring the webhook content rules
    Add Webhook Content Rule
    ...    title=Start a Demo instance for new content
    ...    event=Object added to this container
    ...    url=${ENGINE_URL}/process-definition/key/Demo/start
    ...    payload=${START_PAYLOAD}
    Add Webhook Content Rule
    ...    title=Signal Operaton when content is modified
    ...    event=Object modified
    ...    url=${ENGINE_URL}/signal
    ...    payload=${MODIFIED_PAYLOAD}
    Add Webhook Content Rule
    ...    title=Signal Operaton when content is removed
    ...    event=Object removed from this container
    ...    url=${ENGINE_URL}/signal
    ...    payload=${DELETED_PAYLOAD}
    Take Screenshot    ${SHOTS_DIR}/webhook-content-lifecycle-rules-applied.png
    [Teardown]    End Actor Turn

Administrator Adds Two Documents
    [Documentation]    Content lifecycle · 2 / 5. Each new document starts
    ...    its own Demo instance, parked on "Review page" -- one document
    ...    will be modified, the other removed, further on.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Content lifecycle · 2 / 5
    ...    title=Administrator    subtitle=Adding the two documents
    Go To    ${BASE_URL}
    Add Content    Document    ${DOC_TITLE_MODIFIED}
    Go To    ${BASE_URL}
    Add Content    Document    ${DOC_TITLE_DELETED}
    Take Screenshot    ${SHOTS_DIR}/webhook-content-lifecycle-documents-added.png
    [Teardown]    End Actor Turn

Cockpit Shows Both Instances Running
    [Documentation]    Content lifecycle · 3 / 5. Both instances are on
    ...    "Review page", waiting for either boundary event -- proof the
    ...    earlier rule started them before this story does anything to end
    ...    either one.
    Wait For Process Instance In Cockpit    Demo
    Take Screenshot    ${SHOTS_DIR}/webhook-content-lifecycle-both-running.png

Administrator Modifies A Document
    [Documentation]    Content lifecycle · 4 / 5. Editing the document fires
    ...    the "modified" rule, which signals Operaton with this exact
    ...    document's own UUID -- only its own instance's boundary event
    ...    matches, ending it at "Ended: content modified" while the other
    ...    document's instance stays untouched.
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Content lifecycle · 4 / 5
    ...    title=Administrator    subtitle=Modifying a document to signal its own instance
    Go To    ${BASE_URL}/${DOC_PATH_MODIFIED}
    Edit Current Document
    Take Screenshot    ${SHOTS_DIR}/webhook-content-lifecycle-document-modified.png
    [Teardown]    End Actor Turn

Administrator Deletes The Other Document
    [Documentation]    Content lifecycle · 5 / 5. Removing the other
    ...    document fires the "removed" rule the same way, ending its own
    ...    instance at "Ended: content removed".
    [Setup]    Start Actor Turn    ${ADMIN_USER}
    ...    eyebrow=Content lifecycle · 5 / 5
    ...    title=Administrator    subtitle=Removing the other document to signal its own instance
    Go To    ${BASE_URL}/${DOC_PATH_DELETED}
    Delete Current Document
    Take Screenshot    ${SHOTS_DIR}/webhook-content-lifecycle-document-deleted.png
    [Teardown]    End Actor Turn

Wrap Up In Cockpit
    [Documentation]    Both instances now show up in Cockpit's History, each
    ...    ended at its own boundary event's end event -- proof the signals
    ...    reached the right instance, not just any instance waiting on that
    ...    boundary.
    Show Completed Instance In Cockpit History    Demo
    Take Screenshot    ${SHOTS_DIR}/webhook-content-lifecycle-cockpit-history.png
    End Observer
