*** Settings ***
Documentation     Project keywords for documenting collective.webhook content
...               rules that call Operaton's (Camunda 7) REST API, built on
...               the generic screencast.Screencast library (see
...               https://github.com/datakurre/robotframework-screencast).
...               Two keywords carry the whole story:
...
...               `Add Webhook Content Rule` drives Plone's own
...               Site Setup > Content Rules UI -- the same steps
...               https://collective.github.io/collective.webhook/ documents
...               by hand -- to wire a "Call webhook" action to an Operaton
...               REST endpoint.
...
...               `Wait For Process Instance In Cockpit` then confirms, from
...               Operaton's own side, that the call actually arrived: the
...               same check regardless of whether it started, correlated a
...               message to, or signalled the process instance.
...
...               See webhook_message.robot, webhook_signal.robot,
...               webhook_process_start.robot and
...               webhook_content_lifecycle.robot for the four scenarios
...               built on them, and README.md in this directory for how
...               they relate. collective/collective.bpmproxy's own BPM
...               Message and BPM Signal content-rule actions
...               (https://github.com/collective/collective.bpmproxy) are a
...               higher-level alternative to typing the raw Operaton REST
...               calls in a collective.webhook payload by hand -- they carry
...               engine credentials, multi-tenancy and per-document signal
...               correlation for you (see
...               profiles/default/contentrules.xml there), at the cost of
...               an extra add-on.
Library           screencast.Screencast
Library           webhook_keywords.py


*** Variables ***
# The proxy Codespaces/`make start` forward: Plone answers at its root and
# Operaton's web apps at /operaton (see the repository README's "How it fits
# together"). The engine's own REST API is not proxied -- Plone calls it
# directly, server to server, at the address the README's own curl example
# uses.
${PROXY_URL}      http://localhost:8000
${BASE_URL}       ${PROXY_URL}
${ENGINE_URL}     http://localhost:8800/engine-rest
${COCKPIT_URL}    ${PROXY_URL}/operaton/app/cockpit/default
# The playground's only Plone user (see README.md's "Getting started" table).
${ADMIN_USER}         admin
${ADMIN_PASSWORD}    admin


*** Keywords ***
Add Webhook Content Rule
    [Documentation]    Create a content rule named `title`, triggered by
    ...    `event` -- one of Plone's built-in "Triggering event" choices,
    ...    e.g. "Object added to this container" or "Workflow state
    ...    changed" -- add a "Call webhook" action that calls `method` on
    ...    `url` with `payload` as its JSON payload (use `${url}`/`${title}`/
    ...    `${uid}`/… to interpolate values from the triggering content, per
    ...    collective.webhook's own substitutions table -- `${uid}` is its
    ...    own UUID token, registered in
    ...    src/collective/webhook/adapters.py; collective.bpmproxy registers
    ...    a differently named `${uuid}` for the same value, which is not
    ...    available here since this playground does not install it), and
    ...    apply the rule to the whole site.
    ...
    ...    When `event` is "Workflow state changed", pass one or more
    ...    `transitions` -- by their internal id (e.g. "publish", "retract"),
    ...    not their visible title -- to also add Plone's own "Workflow
    ...    transition" condition, so the webhook only fires for those
    ...    transitions -- otherwise every occurrence of `event` anywhere on
    ...    the site calls it.
    [Arguments]    ${title}    ${event}    ${url}    ${payload}
    ...    ${method}=POST    @{transitions}
    Go To    ${BASE_URL}/@@rules-controlpanel
    Human Click    role=link[name="Add content rule"]
    Human Type    label=Title    ${title}
    Select Option    label=Triggering event    ${event}
    Human Click    role=button[name="Save"]
    IF    ${{ len($transitions) > 0 }}
        Select Option    \#contentrules-add-condition    Workflow transition
        Human Click    button[name="form.button.AddCondition"]
        Select Option    \#form-widgets-wf_transitions    ${transitions}
        Human Click    role=button[name="Save"]
    END
    Select Option    \#contentrules-add-action    Call webhook
    Human Click    button[name="form.button.AddAction"]
    Human Type    label=Webhook URL    ${url}
    Select Option    label=Call method    ${method}
    Human Type    label=JSON payload    ${payload}
    Check    label=Verbose logging
    Human Click    role=button[name="Save"]
    Human Click    role=button[name="Apply rule on the whole site"]

Wait For Process Instance In Cockpit
    [Documentation]    Enter `process_definition_key`'s instance list in
    ...    Cockpit and poll until at least one running instance is listed --
    ...    proof that the webhook actually reached Operaton, whichever of
    ...    the three ways (direct start, message correlation, signal
    ...    broadcast) it used, then open that instance. Call `Log In To
    ...    Cockpit` first in the same take, to have somewhere for `Observe`
    ...    to bring to the front.
    [Tags]    screencast:wait
    [Arguments]    ${process_definition_key}    ${retries}=20x    ${interval}=3s
    Observe    url=${COCKPIT_URL}/#/processes
    Human Click    role=link[name="${process_definition_key}"]
    Wait Until Keyword Succeeds    ${retries}    ${interval}
    ...    Wait Until Visible    a[href*="/process-instance/"]    index=-1    timeout=1000
    Human Click    a[href*="/process-instance/"]    index=-1

Show Completed Instance In Cockpit History
    [Documentation]    Enter `process_definition_key`'s History tab in
    ...    Cockpit and open its most recently completed instance -- proof
    ...    that the instance actually ended (a boundary event firing, for
    ...    instance), since a still-running instance never appears there.
    [Tags]    screencast:wait
    [Arguments]    ${process_definition_key}    ${retries}=20x    ${interval}=3s
    Observe    url=${COCKPIT_URL}/#/processes
    Human Click    role=link[name="${process_definition_key}"]
    Human Click    text=History    index=-1
    Wait Until Keyword Succeeds    ${retries}    ${interval}
    ...    Wait Until Visible    a[href*="/history/process-instance/"]    index=-1    timeout=1000
    Human Click    a[href*="/history/process-instance/"]    index=-1

Log In To Cockpit
    [Documentation]    Complete Cockpit's own login form in an unrecorded
    ...    context and return its storage_state() for `Start Observer` --
    ...    keeps the login redirect out of the recording while carrying the
    ...    session into the recorded one.
    [Arguments]    ${username}=demo    ${password}=demo
    Start Scratch Context    ${COCKPIT_URL}/
    Human Type    role=textbox[name="Username"]    ${username}
    Human Type    role=textbox[name="Password"]    ${password}
    Human Click    role=button[name="Log in"]
    ${state}=    Get Storage State
    End Scratch Context
    RETURN    ${state}

Add Content
    [Documentation]    Add a new content item of `type_name` from the
    ...    current folder view, filling only its title.
    [Arguments]    ${type_name}    ${title}
    Human Click    role=link[name="Add new…"]
    Human Click    role=link[name="${type_name}"]
    Human Type    \#form-widgets-IDublinCore-title    ${title}
    Human Click    role=button[name="Save"]

Publish Current Document
    [Documentation]    Fire the "Publish" workflow transition on the
    ...    document currently open, from Plone's own contentmenu.
    Human Click    \#plone-contentmenu-workflow a
    Human Click    role=link[name="Publish"]

Edit Current Document
    [Documentation]    Open the document currently open for editing and
    ...    re-save it with an updated Description -- enough to fire Plone's
    ...    "Object modified" event without changing what the document is
    ...    about.
    [Arguments]    ${description}=Updated by the webhook screencast.
    Human Click    role=link[name="Edit"]
    Human Type    \#form-widgets-IDublinCore-description    ${description}
    Human Click    role=button[name="Save"]

Delete Current Document
    [Documentation]    Delete the document currently open, through Plone's
    ...    own "Actions" contentmenu and its delete confirmation page --
    ...    fires "Object removed from this container".
    Human Click    \#plone-contentmenu-actions a
    Human Click    role=link[name="Delete"]
    Human Click    role=button[name="Delete"]
