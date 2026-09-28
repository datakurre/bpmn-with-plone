# Webhook screencasts

Four [Robot Framework](https://robotframework.org/) stories, built with
[`robotframework-screencast`](https://github.com/datakurre/robotframework-screencast),
that document how to configure
[`collective.webhook`](https://github.com/collective/collective.webhook)
content rules to call Operaton's (Camunda 7) REST API -- the same technique
introduced in [`docs/src/patterns.md`](../../docs/src/patterns.md)'s
"Content lifecycle signals" section and
[`docs/src/setup.md`](../../docs/src/setup.md)'s "Plone" section, worked
through step by step against this repository's own playground
(`make install && make start`; see the repository README). All four have
been run for real against that playground -- not just dry-run `screencast
check` -- and `screencast verify` reports no findings for any of them.

Each story reads like a screenplay: an Administrator configures the content
rule(s) through Plone's UI, then triggers them, while Operaton Cockpit
observes throughout and shows the resulting process instances. All four
drive the same deployed process, `docs/src/diagrams/ping.bpmn` (process key
`Demo`), which has three ways in and two ways for a running instance to be
signalled back:

| Scenario | `webhook_*.robot` | Content-rule event | REST call | BPMN element |
|---|---|---|---|---|
| Send a message | `webhook_message.robot` | Object added to this container | `POST {ENGINE_URL}/message` | message start event `plone` -- correlates to the instance already waiting on it, the same delivery the main README's `curl` example makes by hand |
| Send a signal | `webhook_signal.robot` | Workflow state changed, condition: Workflow transition = Publish | `POST {ENGINE_URL}/signal` | signal start event `plone` -- a signal broadcasts, so this always starts a *new* instance |
| Start a process | `webhook_process_start.robot` | Object added to this container | `POST {ENGINE_URL}/process-definition/key/Demo/start` | plain ("none") start event -- no message or signal on the process side at all |
| React to content changing | `webhook_content_lifecycle.robot` | Object added (start), Object modified, Object removed from this container | `POST .../start`, then `POST {ENGINE_URL}/signal` twice | two **interrupting boundary signal events** on the "Review page" user task, `demo-content-modified:${uuid}` / `demo-content-deleted:${uuid}` -- see below |

The first three are the minimal, one-shot cases: something happens once in
Plone, Operaton hears about it once. `webhook_content_lifecycle.robot` is
the more useful pattern in practice -- a process that keeps listening to
*the same* Plone document throughout its own lifetime, and reacts when that
document is later modified or removed, not only to what started it. See
`docs/src/patterns.md` for the general pattern, and
webhook_content_lifecycle.robot's own Documentation for why its payloads use
`${uid}`, not `${uuid}` -- `collective.webhook` and `collective.bpmproxy`
each register their own, differently named interpolation token for a
content's UUID, and only `collective.webhook`'s is available in this
playground. `collective.bpmproxy`'s own
[`examples/published-lifecycle/example-published-lifecycle.bpmn`](https://github.com/collective/collective.bpmproxy/blob/main/examples/published-lifecycle/example-published-lifecycle.bpmn)
and
[`backend/src/collective/bpmproxy/profiles/default/contentrules.xml`](https://github.com/collective/collective.bpmproxy/blob/main/backend/src/collective/bpmproxy/profiles/default/contentrules.xml)
are the richer, production original of this same technique, using its
dedicated BPM Signal content-rule action instead of a raw
`collective.webhook` payload.

## The project keywords

`resources/webhook.resource` adds keywords on top of the engine's own (see
the `screencast` agent skill's `SKILL.md` for those). Two carry the whole
story, the rest are small supporting keywords the four stories share:

- **`Add Webhook Content Rule`** drives Site Setup > Content Rules exactly as
  [`collective.webhook`'s own documentation](https://collective.github.io/collective.webhook/)
  describes: add a rule, pick its triggering event, add a "Call webhook"
  action with a URL/method/JSON payload, and apply it to the whole site.
  Passing one or more `transitions` -- by their internal id (e.g.
  `publish`, not the visible title "Publish") -- also adds Plone's built-in
  "Workflow transition" condition (used by the signal scenario to fire only
  on that transition). It also checks "Verbose logging": that field is
  required despite being a plain checkbox (an unchecked box submits
  nothing, and the field has no default), so leaving it unchecked fails to
  save.
- **`Wait For Process Instance In Cockpit`** confirms, from Operaton's own
  side, that a webhook call actually arrived: it polls a process
  definition's instance list in Cockpit until an instance shows up, then
  opens it. The same keyword works regardless of whether an instance was
  started directly, correlated by message, or created by a signal.
- `Show Completed Instance In Cockpit History` is the same idea for an
  instance that has since *ended* -- used by the content-lifecycle scenario
  to prove a boundary event actually fired, since a still-running instance
  never appears in Cockpit's History tab.
- `Log In To Cockpit`, `Add Content`, `Publish Current Document`, `Edit
  Current Document` and `Delete Current Document` are the small UI actions
  the stories trigger the rules with. All four stories add a "Page" -- the
  Plone 6 UI's visible name for the `Document` content type; `Add Content`
  matches by what "Add new…" actually shows, not the underlying portal
  type.

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

The other scenarios run the same way, with `webhook_signal.robot` /
`webhook_process_start.robot` / `webhook_content_lifecycle.robot` in place
of `webhook_message.robot`.

Each story only removes its own leftover demo document(s) before recording;
it leaves the content rule(s) it created in place. Running more than one
scenario against the same site means more than one "Call webhook" rule is
applied to the whole site at once -- harmless for these four (each is
scoped to a different Operaton REST endpoint and, for the signal and
content-lifecycle scenarios, a different triggering event), but disable or
remove a rule from Site Setup > Content Rules first if that is not what you
want, or start from a fresh `make clean install`.
