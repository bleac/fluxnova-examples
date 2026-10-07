# Fluxnova Agentic Subprocess Demo

A BPMN **ad-hoc subprocess** driven by an LLM. The engine sends the model a system prompt and
some process variables. The model picks which activities of the subprocess to run, sees their
results, and keeps going until it stops calling tools. Everything runs as normal BPMN: every step
is visible in Monitoring, and a human can be one of the tools.

The example is a **card dispute triage agent**:

```
(Dispute received) -> [ Dispute triage agent (ad-hoc subprocess)          ] -> <Decision?> -> Provisional credit issued
                      |  Look up customer        Look up transaction      |              -> Dispute rejected
                      |  Issue provisional credit  Reject dispute         |              -> Manual review (no decision)
                      |  Escalate to fraud analyst (user task)            |
```

It uses OpenAI or Anthropic. You need an API key for one of them. Each dispute makes about three
or four model calls.

## Mandatory steps

### 1. Get an API key

Pick **one** provider:

| Provider  | Create a key                                   | Default model      |
|-----------|------------------------------------------------|--------------------|
| OpenAI    | https://platform.openai.com/api-keys           | `gpt-4o-mini`      |
| Anthropic | https://console.anthropic.com/settings/keys    | `claude-haiku-4-5` |

Both require an account with billing set up. Treat the key like a password.

### 2. Configure it

```sh
cp .env.example .env
```

Edit `.env`: set `LLM_PROVIDER` to `openai` or `anthropic`, and fill in that provider's key. For
example:

```sh
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
```

`.env` is git-ignored. Never commit it.

### 3. Start

```sh
docker compose up -d --build
docker compose logs -f fluxnova-service     # wait for "Started Application"
```

The first build takes a few minutes. The engine and web apps are at http://localhost:8080
(login `demo` / `demo`).

### 4. Start a dispute

```sh
curl -H 'Content-Type: application/json' \
  -d '{"businessKey":"DSP-1001","variables":{
        "customerId":{"value":"CUST-1001","type":"String"},
        "transactionId":{"value":"TX-5001","type":"String"},
        "disputeReason":{"value":"I cancelled this subscription last month but was charged again.","type":"String"}}}' \
  http://localhost:8080/engine-rest/process-definition/key/card-dispute-agent/start
```

`rest.http` has all three scenarios:

| Business key | Customer / transaction   | What the system prompt tells the agent to do         |
|--------------|--------------------------|------------------------------------------------------|
| `DSP-1001`   | `CUST-1001` / `TX-5001`  | 12.99 USD, good standing: issue a provisional credit |
| `DSP-1002`   | `CUST-1002` / `TX-5002`  | 2,450 USD at a high-risk merchant: escalate to a human |
| `DSP-1003`   | `CUST-1003` / `TX-5003`  | Restricted account, 4 recent disputes: reject        |

The LLM makes the decision, so it can occasionally differ from the table.

### 5. Watch the agent in Monitoring

Open http://localhost:8080/fluxnova/app/monitoring/ and open **Card Dispute Agent**. While the
agent is working, the instance sits in **Dispute triage agent**, and the tools it calls light up
one after another. On the instance's **Variables** tab you can see `customerProfile`,
`transactionDetails` and `disputeDecision` appear, plus `_agentConversationHistory`, the
conversation with the model.

### 6. Act as the fraud analyst (`DSP-1002`)

When the agent escalates, the process waits for a human. Open
http://localhost:8080/fluxnova/app/tasklist/, pick **Escalate to fraud analyst**, choose a
**Decision** and complete the task. The agent then gets one more turn, sees `disputeDecision` and
stops.

### 7. Check the result

```sh
PI=$(curl -s "http://localhost:8080/engine-rest/history/process-instance?processInstanceBusinessKey=DSP-1001" \
  | sed 's/.*"id":"\([^"]*\)".*/\1/')
curl -s "http://localhost:8080/engine-rest/history/variable-instance?processInstanceId=$PI"
curl -s "http://localhost:8080/engine-rest/history/activity-instance?processInstanceId=$PI&sortBy=startTime&sortOrder=asc"
```

`disputeDecision` is `PROVISIONAL_CREDIT` or `REJECTED`, and `decidedBy` is `agent` or `analyst`.
The activity list shows which tools ran and which end event was reached.

Stop with `docker compose down` (add `-v` to delete the data).

## How it works

The model is in `fluxnova-service/src/main/resources/processes/card-dispute-agent.bpmn`.

- **`agent:config`** on the ad-hoc subprocess turns it into an agent: `provider`, `model` and
  `systemPrompt`. The system prompt holds the business rules.
- **`agent:context`** lists the process variables the model sees. They are re-read before every
  turn, which is how the model learns what a tool produced.
- **Every child activity is a tool.** Its id is the tool name, and its `name` and
  `documentation` become the tool description. Tools take no arguments from the model: they read
  process variables through input mappings and write results through output mappings.
- **A user task can be a tool** (`escalateToAnalyst`). The agent waits until a person completes it.
- **The process keeps control.** After the agent finishes, a gateway routes on `disputeDecision`.
  If the agent ended without a decision, the case goes to **Manual review**.

The tools call `DisputeData.java`, an in-memory stand-in for the bank's systems.

## Things to know

- **The plugins are installed by a script.** The agentic subprocess plugins
  (`1.0.0-SNAPSHOT`) are published to the Sonatype snapshot repository, but their parent POM
  (`org.finos.fluxnova.bpm:fluxnova-plugins:1.0.0`) is not, so Maven cannot resolve them.
  `fluxnova-service/install-agentic-plugins.sh` installs the published JARs locally, and the
  Dockerfile runs it. For a local build outside Docker, run it once, then `mvn package`.
- **The BPMN `model` attribute is not used yet.** It is required, but the plugin does not pass it
  to the provider. Set the model with `OPENAI_MODEL` or `ANTHROPIC_MODEL` instead.
- `provider="llm"` in the BPMN is mapped to the selected provider's chat model in
  `application.yml` (`fluxnova.ai.agent.provider-overrides`), so switching `LLM_PROVIDER` needs no
  BPMN change.
- A missing or wrong API key does not stop the application from starting. The agent's first
  model call fails, and Monitoring shows an incident on **Dispute triage agent**. Check
  `docker compose logs fluxnova-service`.
