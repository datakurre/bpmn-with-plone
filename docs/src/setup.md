# Example Setup

This guide describes the pieces used to run the BPMN-with-Plone examples. The
main components are Plone, the Operaton process engine, and any external task
workers used by a process. They communicate over HTTP, so each component must
be able to reach the others by their service URLs.

## Prerequisites

- Docker, for running Operaton locally.
- A Plone site where you can install add-ons and configure content rules.
- Python 3.10 or later if you are writing a worker with `operaton-tasks`.
- VS Code with extension for editing BPMN models and code.

For a quick start with the complete project environment, open the project in
[GitHub Codespaces](https://codespaces.new/datakurre/bpmn-with-plone). The
project's development-container configuration is the source of truth for its
recommended editor extensions and tools.

## Plone

The Plone integration uses
[`collective.webhook`](https://github.com/collective/collective.webhook), a
content-rule action that sends an HTTP GET or POST request with a JSON payload
when a content event occurs. This lets a Plone event start or notify a process
without embedding process-engine code in Plone.

1. Install `collective.webhook` in the Plone environment using the method for
   that deployment (for example, add it to the project's Python dependencies
   and package includes). Follow the add-on's
   [installation and configuration documentation](https://collective.github.io/collective.webhook/)
   for details specific to your Plone version and deployment tooling.
2. In Plone, create or edit a content rule and choose the webhook action.
   Select the event and conditions that should trigger the request.
3. Configure the target URL, HTTP method, and JSON body. For example, a rule
   might `POST` to Operaton's process-start REST endpoint:

   ```text
   http://operaton:8080/engine-rest/process-definition/key/publication/start
   ```

   The hostname and process key are examples: use the address reachable from
   the Plone server and the key of your deployed process. Configure a request
   body that supplies the variables expected by the BPMN process. For example,
   the Operaton REST API accepts variables in this shape:

   ```json
   {
     "variables": {
       "content_url": {"value": "https://plone.example/content/item", "type": "String"}
     }
   }
   ```

   Replace the example URL with a value from the Plone content item. The
   webhook add-on supports interpolated JSON; use its documentation for the
   supported interpolation syntax.

   ```{figure} images/webhook-content-rule.png
   :alt: A saved Plone content rule named "Notify Operaton of new content", showing its Call webhook action as "POST http://localhost:8800/engine-rest/message (verbose)" and applied to the whole site
   :width: 80%
   :align: center

   A configured rule, as Plone shows it back after saving: the action's summary line is the quickest way to confirm the URL, method and verbose flag actually took.
   ```

   `collective.webhook`'s "Verbose logging" field is required in the form's
   own validation, even though it is a plain checkbox -- leave it unchecked
   (an unchecked HTML checkbox submits nothing at all, not `false`) and
   saving fails with "Please check this box if you want to proceed."; check
   it to save, which usefully also logs the request and response while you
   are still setting things up.
4. Trigger the rule with test content and verify both the webhook request and
   the resulting process instance in Operaton.

The webhook request is made after the Plone transaction commits, and the
request that triggered the rule waits for the HTTP response. Plan for the
engine to be reachable from Plone, and review the add-on's behavior and error
handling before using it for high-volume or production workflows. If Plone and
Operaton run in separate containers, `localhost` in a URL refers to the
container making the request; use a shared Docker network or an address
reachable from that container instead.

A content rule can call any of Operaton's REST endpoints the same way, not
only process start: `POST` to `/message` to correlate a BPMN message, or to
`/signal` to broadcast a signal -- and a signal named after the content's own
UUID lets an already-running instance react later to that same content being
modified or removed; see [Content lifecycle signals](patterns.md#content-lifecycle-signals).
[`scripts/screencasts/`](https://github.com/collective/bpmn-with-plone/tree/main/scripts/screencasts)
in this repository's source walks through all of these against this
playground's own `ping.bpmn`, as four
[`robotframework-screencast`](https://github.com/datakurre/robotframework-screencast)
stories built on a handful of project keywords (one to configure a rule
through Plone's UI, others to confirm a call arrived in, or a boundary event
ended an instance in, Operaton Cockpit).
[`collective.bpmproxy`](https://github.com/collective/collective.bpmproxy)
provides dedicated BPM Message and BPM Signal content-rule actions as a
higher-level alternative to typing the raw REST call in a `collective.webhook`
payload by hand.

## Operaton

Operaton executes BPMN processes and provides the REST API and web applications
used to deploy and inspect them. The examples here use a Docker image that adds
Cockpit plugins for process history views. Those plugins extend the web UI;
they are not required by the process engine to execute BPMN.

Build and run the image from the
[`operaton-cockpit-plugins`](https://github.com/datakurre/operaton-cockpit-plugins)
repository:

```shell
# Build directly from GitHub without cloning:
curl -fsSL https://raw.githubusercontent.com/datakurre/operaton-cockpit-plugins/main/Dockerfile | docker build -t operaton-with-plugins -

# Or, from a local clone of the repository:
docker build -t operaton-with-plugins - < Dockerfile

# Run Operaton and publish its web port:
docker run --rm -p 8080:8080 operaton-with-plugins
```

When the container is ready, open
[`http://localhost:8080/operaton/app/cockpit/`](http://localhost:8080/operaton/app/cockpit/)
to access Cockpit. The plugin project's local demo uses the `demo` / `demo`
credentials; use appropriate authentication and engine configuration for any
non-local deployment. This `docker run` command is intended for a disposable
local instance, not a persistent production database.

Deploy a BPMN process before configuring Plone or a worker to call it. For
background on deploying processes and using Operaton's REST API, see the
[Operaton documentation](https://docs.operaton.org/).

## External task workers

Use an external task when a process needs work performed by a separate service
or program. In the BPMN model, configure the service task as an external task
with a topic. A worker polls Operaton for tasks subscribed to that topic,
performs the work, and reports completion or failure through the REST API.
Keep the topic names in the BPMN model and worker configuration in sync.

[`operaton-tasks`](https://github.com/vasara-bpm/operaton-tasks) provides a
Python worker library and an optional command-line runner. In a Python
environment, install its CLI extra:

```shell
python -m pip install "operaton-tasks[cli]"
```

Create a Python module with an async handler registered for the BPMN task's
topic, then run that module with the CLI. For example, with a handler module
named `my_tasks.py` and Operaton available at `http://localhost:8080`:

```python
# my_tasks.py
import operaton.tasks
from operaton.tasks.types import (
    CompleteExternalTaskDto,
    ExternalTaskComplete,
    LockedExternalTaskDto,
)


@operaton.tasks.register("send-notification")
async def send_notification(task: LockedExternalTaskDto) -> ExternalTaskComplete:
    # Read task variables, perform the work, and return a completion result.
    return ExternalTaskComplete(
        task=task,
        response=CompleteExternalTaskDto(workerId=task.workerId),
    )
```

The topic passed to `register` (`send-notification` here) must match the topic
configured on the external service task in the BPMN model. A real handler
should perform its intended work and can return process variables when needed.

```shell
export ENGINE_REST_BASE_URL="http://localhost:8080/engine-rest"
operaton-tasks serve ./my_tasks.py
```

The handler API and complete examples are documented in the
[`operaton-tasks` project README](https://github.com/vasara-bpm/operaton-tasks).
If the engine requires authentication, configure the worker's supported
authorization or OAuth2 environment variables as described there. Do not put
credentials in the BPMN file or commit them to source control. When the worker
runs in a container, set the engine URL to a hostname it can resolve on its
network; `localhost` only works when the engine shares that network namespace.

## VS Code

The development container installs these VS Code extensions:

- `datakurre.vscode-operaton-bpmn-js-modeler`
- `datakurre.vscode-operaton-dmn-js-modeler`
- `datakurre.vscode-operaton-form-js-modeler`
- `ms-python.python`
- `ms-python.vscode-pylance`

Opening the project in Codespaces applies this setup automatically. In a local
VS Code installation, install these extensions and open the project folder
rather than an individual documentation file so workspace settings and
extension recommendations are available. The extension list is defined in
`.devcontainer/devcontainer.json`.

## Verify the setup

Once the services are available, check each connection in order:

1. Open the Operaton web application and confirm the engine is running.
2. Deploy a BPMN model and verify that it appears in Cockpit.
3. Trigger a Plone content rule and confirm that the expected process instance
   starts.
4. If the process uses external tasks, start the worker and confirm it picks up
   the matching topic and completes the task.

If a step fails, check the service logs and verify that the URL is reachable
from the service making the request. A URL that works in your browser may not
be reachable from a Plone or worker container.
