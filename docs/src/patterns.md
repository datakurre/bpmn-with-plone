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

### TODO

* How to wire this pattern to `collective.webhook`

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

### TODO

* How to wire this pattern to `collective.webhook`
* How processes connect to content
* How to propagate content-state changes to the engine

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
