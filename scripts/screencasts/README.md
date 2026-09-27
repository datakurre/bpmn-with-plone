# Webhook screencasts

Three [Robot Framework](https://robotframework.org/) stories, built with
[`robotframework-screencast`](https://github.com/datakurre/robotframework-screencast),
that document how to configure
[`collective.webhook`](https://github.com/collective/collective.webhook)
content rules to call Operaton's (Camunda 7) REST API -- the same technique
introduced in [`docs/src/setup.md`](../../docs/src/setup.md)'s "Plone"
section, worked through step by step against this repository's own
playground (`make install && make start`; see the repository README).

Each story reads like a screenplay: an Administrator configures the content
rule through Plone's UI, then triggers it, while Operaton Cockpit observes
throughout and shows the resulting process instance. All three drive the
same deployed process, `docs/src/diagrams/ping.bpmn` (process key `Demo`),
which now has three ways in:

| Scenario | `webhook_*.robot` | Content-rule event | REST call | BPMN entry point |
|---|---|---|---|---|
| Send a message | `webhook_message.robot` | Object added to this container | `POST {ENGINE_URL}/message` | message start event `plone` -- correlates to the instance already waiting on it, the same delivery the main README's `curl` example makes by hand |
| Send a signal | `webhook_signal.robot` | Workflow state changed, condition: Workflow transition = Publish | `POST {ENGINE_URL}/signal` | signal start event `plone` -- a signal broadcasts, so this always starts a *new* instance |
| Start a process | `webhook_process_start.robot` | Object added to this container | `POST {ENGINE_URL}/process-definition/key/Demo/start` | plain ("none") start event -- no message or signal on the process side at all |

## The two project keywords

`resources/webhook.resource` adds two keywords on top of the engine's own
(see the `screencast` agent skill's `SKILL.md` for those), everything else in
it is a small supporting keyword the three stories share:

- **`Add Webhook Content Rule`** drives Site Setup > Content Rules exactly as
  [`collective.webhook`'s own documentation](https://collective.github.io/collective.webhook/)
  describes: add a rule, pick its triggering event, add a "Call webhook"
  action with a URL/method/JSON payload, and apply it to the whole site.
  Passing one or more `transitions` also adds Plone's built-in "Workflow
  transition" condition (used by the signal scenario to fire only on
  Publish).
- **`Wait For Process Instance In Cockpit`** confirms, from Operaton's own
  side, that the webhook call actually arrived: it polls a process
  definition's instance list in Cockpit until an instance shows up, then
  opens it. The same keyword works for all three scenarios -- Cockpit does
  not care whether an instance was started directly, correlated by message,
  or created by a signal.

## Running a scenario

With the playground's services running (`make start`, or already running in
Codespaces) and this package installed (it is not on PyPI -- see the
`screencast` skill's `SKILL.md`, or
<https://github.com/datakurre/robotframework-screencast>):

```sh
screencast check scripts/screencasts/webhook_message.robot   # dry run, no browser
screencast run scripts/screencasts/webhook_message.robot --take /tmp/webhook-message
screencast compose /tmp/webhook-message
screencast verify /tmp/webhook-message
```

The other two scenarios run the same way, with `webhook_signal.robot` /
`webhook_process_start.robot` in place of `webhook_message.robot`.

Each story only removes its own leftover demo document before recording; it
leaves the content rule it created in place. Running more than one scenario
against the same site means more than one "Call webhook" rule is applied to
the whole site at once -- harmless for these three (each is scoped to a
different Operaton REST endpoint and, for the signal scenario, a different
triggering event), but disable or remove a rule from Site Setup > Content
Rules first if that is not what you want, or start from a fresh
`make clean install`.
