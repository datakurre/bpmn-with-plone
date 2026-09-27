# BPMN with Plone

**This documentation is still a draft.**

This project documents how to use [BPMN 2.0](https://www.omg.org/spec/BPMN/) business process models with [Plone](https://plone.org/).

BPMN stands for **Business Process Model and Notation**, an OMG standard.
BPMN provides **a visual language** that everyone from domain experts to business analysts and developers can understand.
BPMN 2.0 also defines an **executable XML format** with strict operational semantics.
Because process engines execute BPMN models directly, BPMN can eliminate the translation gap between a process specification and production code. BPMN becomes the **production code**.

This documentation accompanies a playground, which you can open in [GitHub Codespaces](https://codespaces.new/collective/bpmn-with-plone).

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/collective/bpmn-with-plone)

## About states and activities

**Plone workflows describe a content object's state** and the transitions available from that state.
**BPMN describes the work performed over time** by mode the activities and sequence of a business process.
Plone focuses on an individual document; BPMN models a process that can coordinate work across people and systems.
**They address different concerns and can complement each other.**

`````{grid} 1 1 2 2

````{grid-item}
### Plone Workflow

```{figure} images/simple-publication-workflow.png
:alt: The simple publication workflow with Private, Pending Review, and Published states
:width: 100%

State diagram of Plone’s simple publication workflow, showing its three states and their transitions.
```
````

````{grid-item}
### BPMN

```{bpmn} diagrams/simple-publication.bpmn
:mode: svg
:alt: BPMN publication process with author and reviewer lanes, draft creation, review, and message flows to Plone CMS
:width: 80%
:align: center
:caption: BPMN model of the publication process, with author and reviewer lanes and message flows to Plone CMS.
```
````
`````

## Collaboration between BPMN and Plone

For users, Plone is a tool to help them to complete their work. Activity-based workflow like the ones defined with BPMN focus on users and their work. Users may *Create drafts and submit them* for publication, and *Review* them. Eventually the process completes, but Plone continues to manage the state of the resulting artifact, to be there for future editorial processes when required.

```{bpmn} diagrams/simple-publication.bpmn
:mode: interactive
:alt: BPMN publication process with author and reviewer lanes, draft creation, review, and message flows to Plone CMS
:width: 80%
:align: center
:caption: Try the token simulator: start a simulation, click the start event, then click enabled activities and sequence flows to advance the token through the process. Reset the simulation to try again.
```

Use the `:align:` option to position a diagram within its available width.
Set it to `left` (the default), `center`, or `right`.

## Why external process engine?

When BPMN is used to model and orchestrate work performed mainly by users or systems outside Plone, it is natural for that process to be managed by a dedicated service: a BPMN engine. This separates the concerns of managing content (Plone) from managing work (BPMN), and makes it straightforward to integrate with systems other than Plone.

`````{grid} 1 1 2 2

````{grid-item}
```{figure} images/operaton-cockpit.png
:alt: Operaton Cockpit UI
:width: 100%
```
````

````{grid-item}
Our recommended BPMN engine is [Operaton](https://operaton.org): a free and open source engine, licensed under the OSI-approved Apache 2.0 license, and maintained by its community rather than owned by a single company.

Operaton is a community fork of Camunda 7 CE, a mature, Apache 2.0-licensed BPMN 2.0 engine. It runs on the Java runtime, is extensible with Spring, and provides the process engine itself, a REST API, and the web UI shown here.

[Check the Operaton FAQ for more information about it](https://operaton.org/faq/), or [join their Slack from their homepage](https://operaton.org/) to ask more.
````
`````

## External Service Task pattern

BPMN's basic activity types include {bpmn}`diagrams/user-task.bpmn` **User Tasks**, {bpmn}`diagrams/script-task.bpmn` **Script Tasks**, and {bpmn}`diagrams/service-task.bpmn` **Service Tasks**. A User Task is usually a form, whose data is then submitted to the engine. A Script Task runs within the engine itself, useful for transforming data between activities. A Service Task describes work that is usually executed outside the engine.

```{bpmn} diagrams/activity-task-types.bpmn
:mode: svg
:alt: A BPMN process with a User Task, a Script Task, and a Service Task activity.
:width: 80%
:align: center
:caption: The three basic BPMN activity types, a user task, a script task, and a service task.
```

The **external service task** pattern is the recommended approach for automating work with an external process engine. Rather than customizing the engine itself for domain-specific automation, this pattern keeps the engine as-is for easy maintenance, and implements domain-specific task automation and integrations as external workers. This decouples process automation from task automation. Workers can run anywhere and scale horizontally.

```{bpmn} diagrams/scheduled-publication.bpmn
:mode: interactive
:alt: BPMN scheduled publication process with a message start event, a script task calculating the publication time, a timer event, and an external service task that publishes to Plone
:width: 80%
:align: center
:caption: An external service task publishes content in Plone once its scheduled publication time is reached.
```

For example, with the Operaton engine:

1. The engine creates a task for the configured topic.
2. A worker fetches and locks the service task.
3. The worker executes the automation and completes the task.
4. The engine handles retries and failure incidents.

## Contents


```{toctree}
:maxdepth: 1

patterns
setup
operaton
```
