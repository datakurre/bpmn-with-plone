# Integration patterns

This page describes common patterns for integrating Plone with an external BPMN process orchestration engine.

## Fire and forget

In this fire-and-forget pattern, Plone sends a request to start work and does not need a response when the process finishes.
The diagram shows a message start event for Plone's request and a regular start event for work started independently; both paths converge before the service task.
The process completes the work and ends without sending a message back to Plone.
For this pattern, Plone needs only integration to start the process, usually through the engine REST API.

```{bpmn} diagrams/fire-and-forget.bpmn
:mode: interactive
:alt: Plone sends a request to a BPMN process, which performs work and completes without returning a message.
:width: 80%
:align: center
```

Wire the message start event to `collective.webhook` with a content rule that `POST`s to Operaton's `/message` endpoint:

```json
{"messageName": "work-requested"}
```

Operaton's message-correlation endpoint starts a new instance from a matching message start event whenever no running instance is already waiting on that message, so a plain `POST` is enough here -- there is nothing to correlate to yet. [`scripts/screencasts/webhook_message.robot`](https://github.com/collective/bpmn-with-plone/blob/main/scripts/screencasts/webhook_message.robot) in this repository's source works through the same call, against this playground's own deployed process, as a runnable example.

## Complementary

In the complementary pattern, Plone sends a request to start a process, and the process sends an update to Plone when its work completes.
The process runs its work in a service task, then uses a message end event to send the update.
This lets the BPMN engine coordinate work while Plone receives an event to update its content or workflow state.
For this pattern, configure the message end event as an external task in Operaton.
A worker subscribed to its topic can then submit the update to Plone through its REST API.

```{bpmn} diagrams/complementary.bpmn
:mode: interactive
:alt: Plone sends a request to a BPMN process, which performs work and sends an update back to Plone.
:width: 80%
:align: center
```

The request leg is wired the same way as fire and forget: a content rule `POST`s to `/message` (or `/process-definition/key/.../start`; see [setup.md](setup.md)) to start the instance. The update leg is an external task, not a webhook: configure the message end event's `camunda:topic` and run a worker (see setup.md's "External task workers") that calls Plone's own REST API (`plone.restapi`) to update the content or move its workflow state once the work completes.

A process connects back to *the same* piece of content by carrying its identity as a process variable -- typically Plone's own UUID, since it survives moves and renames. The content rule's JSON payload sets it once, from `${uid}` -- `collective.webhook`'s own interpolation token for a content's UUID -- when the instance starts:

```json
{"variables": {"uuid": {"value": "${uid}", "type": "String"}}}
```

From there, the worker (or a script task) can look content up by UUID through `plone.restapi`'s `@querystring`/`@search` endpoints, or (for a message or signal correlated *back* to this instance) as a correlation key or part of the signal's name -- see "Content lifecycle signals" below for propagating further content-state changes, such as an edit or a deletion, to an already-running instance.

## Content lifecycle signals

The patterns above all show a single request-response between Plone and a process. A running instance can also keep listening, for its own lifetime, to *the same* piece of content changing further -- an edit, or its removal -- not only to what started it. Operaton's `/signal` endpoint always broadcasts a signal by name to every execution currently waiting on it, so the trick is naming the signal after the specific content's own UUID, and having the process do the same:

```{bpmn} diagrams/content-lifecycle.bpmn
:mode: interactive
:alt: A process is started for new Plone content, then a user task carries two boundary signal events, one for the content being modified and one for it being removed, each ending the process differently.
:width: 80%
:align: center
:caption: A user task with two interrupting boundary signal events, named after the content's own UUID, reacting to that content changing while the task is still open.
```

The `${uuid}` in the diagram above and `${uid}` used below look alike but are not the same placeholder, resolved by two different systems at two different times -- they only need to agree on the *value*, which they do because both ultimately come from the same Plone content's UUID:

- In the content rule's own JSON payload, `${uid}` is Plone's own interpolation token for a content's UUID. It is substituted with the *triggering* content's UUID before the HTTP request is even sent. This token is registered by `collective.webhook` itself (as `uid`/`parent_uid`; see its `src/collective/webhook/adapters.py`) -- it is not part of core `plone.stringinterp`, which ships `${url}`/`${title}`/etc. but no UUID token of its own.
- In the BPMN model, `${uuid}` is an Operaton EL expression inside the `bpmn:signal` element's own `name`. It is evaluated per process instance, against that instance's own `uuid` process variable (set from `${uid}` when the instance started, above) at the moment the boundary event's subscription is created -- turning the literal template `demo-content-modified:${uuid}` into a plain string like `demo-content-modified:1e2f...`, resolved from the *instance's* side.

`collective.bpmproxy` happens to register its *own*, differently named `${uuid}`/`${parent_uuid}` interpolation tokens for the same content's-UUID value (see its `adapters/substitutions.py`) -- installing only `collective.webhook`, as this playground does, `${uuid}` in a payload is not a registered token at all, and `plone.stringinterp`'s `string.Template.safe_substitute` leaves an unmatched placeholder as the literal text `"${uuid}"` rather than raising an error. Typing `${uuid}` instead of `${uid}` into a `collective.webhook` payload is therefore a mistake that fails silently: every instance would receive the identical, un-interpolated literal signal name, so every boundary event would fire together instead of only the matching document's own instance. Check what an add-on actually registers (`grep -r IStringSubstitution` in its source, or its `configure.zcml`) before relying on a placeholder name.

Because a fresh instance was started with its `uuid` process variable set from `${uid}` in the first place (see "Complementary", above), both sides land on the same string, and only the matching instance's boundary event fires -- every other instance's subscription is for a different literal signal name and never sees the call. The `uuid` variable is not optional in practice, either: Operaton evaluates a boundary event's EL expression as soon as its enclosing activity starts (creating the signal subscription), so an instance started *without* a `uuid` variable at all fails outright at that point (`Cannot resolve identifier 'uuid'`) rather than merely failing to correlate later.

`````{grid} 1 1 2 2

````{grid-item}
```{figure} images/cockpit-content-lifecycle-running.png
:alt: Operaton Cockpit showing a running Demo instance parked on Review page, with its two boundary signal events and the uuid/contentUrl/contentTitle process variables Plone set when it started
:width: 100%

Two documents, two independent instances, each parked on "Review page" and each carrying its own `uuid` -- Cockpit's Variables tab confirms `${uid}` actually reached Operaton.
```
````

````{grid-item}
```{figure} images/cockpit-content-lifecycle-history.png
:alt: Operaton Cockpit's History audit log for a completed Demo instance, showing the boundarySignal "Content modified" firing and the process ending at "Ended: content modified"
:width: 100%

After editing that document in Plone, its own instance -- and only its own -- ends at "Ended: content modified"; the other stays untouched until its own document is removed.
```
````
`````

| Plone event | Content rule condition | `collective.webhook` call | BPMN element |
|---|---|---|---|
| Object added to this container | none | `POST {ENGINE_URL}/process-definition/key/.../start` with `variables.uuid` set from `${uid}` | plain start event |
| Object modified | none | `POST {ENGINE_URL}/signal` with `name` = `"...:${uid}"` | interrupting boundary signal event on the open task |
| Object removed from this container | none | `POST {ENGINE_URL}/signal` with `name` = `"...:${uid}"` | a second interrupting boundary signal event |

[`scripts/screencasts/webhook_content_lifecycle.robot`](https://github.com/collective/bpmn-with-plone/blob/main/scripts/screencasts/webhook_content_lifecycle.robot)
in this repository's source is a runnable version of exactly this, wired with three plain `collective.webhook` content rules against `docs/src/diagrams/ping.bpmn` -- this playground's own deployed process, which carries the same two boundary events. [`collective.bpmproxy`](https://github.com/collective/collective.bpmproxy)'s own
[`examples/published-lifecycle/example-published-lifecycle.bpmn`](https://github.com/collective/collective.bpmproxy/blob/main/examples/published-lifecycle/example-published-lifecycle.bpmn)
and
[`backend/src/collective/bpmproxy/profiles/default/contentrules.xml`](https://github.com/collective/collective.bpmproxy/blob/main/backend/src/collective/bpmproxy/profiles/default/contentrules.xml)
are the richer, original version of this same technique -- publish, submit, retract, reject, delete and modify, each its own signal -- using bpmproxy's dedicated BPM Signal content-rule action instead of a raw `collective.webhook` payload. That action carries the `${uuid}` interpolation, engine credentials and multi-tenancy for you; the plain `collective.webhook` version above shows what it does underneath.

## Standalone embeds

The standalone embed pattern uses engine-managed forms within a contact-form process.
Submitting the start form creates a process instance, and an administrator reviews the submission in a user task.
The reviewer can reply, which routes the process to an external service task that sends an email, or abandon the contact without sending a reply.
For this pattern, Plone retrieves the forms referenced by the deployed process from the engine, renders them in Plone, and submits the form data to the engine.

```{bpmn} diagrams/standalone-embed.bpmn
:mode: interactive
:alt: A submitted contact form goes to administrator review, then either sends a reply email or ends as abandoned.
:width: 80%
:align: center
```

### TODO

* How to use bpmn-io/form-js to model and render forms
