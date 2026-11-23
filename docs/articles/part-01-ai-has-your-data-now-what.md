# AI Has Your Data. Now What? #1

**Author:** Kevin Wilkie, MBA
**Published:** August 20, 2026
**Original publication:** [LinkedIn article](https://www.linkedin.com/pulse/ai-has-your-data-now-what-1-kevin-wilkie-mba-byjme/)

![Enterprise database security, an AI system, and the expanding data journey](images/part-01.png)

> **Archive note:** This article preserves the original published narrative and technical context. It describes the project's plans at the time of publication, including SQL Server 2025. The current reference implementation has since been validated on SQL Server 2022. For installation, use [Getting Started](../GETTING_STARTED.md); for current limitations, see [Production Readiness](../PRODUCTION_READINESS.md).

# We Have Spent Decades Securing the Database. Then We Connected an AI to It.

We have spent decades figuring out how to secure databases.

We created the following:

Logins.
Roles.
Row-level security.
Column-level security.
Encryption.
Auditing.
Firewalls.
Network segmentation.
Data classification.
Least privilege.

Entire careers have been built around answering one seemingly simple question:

Who is allowed to see this data?
We created a service principal.

We followed least privilege.

We granted it access to the data it needed.

Everything authenticated successfully.

And then the AI started asking for data.

Suddenly, things got more complicated.

Because now the person accessing the data isn't necessarily accessing the database directly.

They might ask:

Which of our customers look like they're having financial trouble?
The AI retrieves some data.

Maybe it searches a vector store.

Maybe it queries a database.

Maybe it calls an API.

Maybe it combines information from five different systems.

Then it reasons over that information and returns an answer.

So, here's a question that I think a lot of organizations are going to have trouble answering:

What exactly did the AI see?
Not what data could it access.

What did it actually see?

And while we're at it:

Who asked the question?
What was the exact prompt?
What system prompt was being used?
Which version of that prompt?
Which model?
Which version of that model?
What context was retrieved?
What database records were accessed?
What tools did the AI call?
What permissions were checked?
What security policies were applied?
What did the model return?
Did something validate that response?
Did the AI take an action based on it?
Did a human approve that action?
And can we prove any of this six months later?

That last question is going to become very important.

## The Prompt Is Only the Beginning
It's tempting to think about an AI interaction like this:

Prompt → AI → Response

That's convenient.

It's also increasingly wrong.

Once we start connecting AI to enterprise data, the interaction looks much more like a data pipeline:

Request → Validate → Authorize → Enrich → Execute → Observe → Validate Response → Persist → Audit

That should look somewhat familiar to data professionals.

We've been building pipelines like this for years.

We validate incoming data.

We determine whether someone is authorized to access something.

We enrich records with information from other systems.

We execute transformations.

We monitor what happened.

We validate the results.

We store enough information to figure out what went wrong when something inevitably does.

But somehow, when AI entered the picture, we started treating the interaction itself as temporary.

Ask a question.

Get an answer.

Move on.

I think that's a mistake.

Because once AI starts interacting with enterprise data:

The AI interaction itself becomes enterprise data.

And we need to start treating it that way.

## What Are We Actually Trying to Protect?
Consider what might exist during one AI interaction.

There's the user's prompt.

That prompt might contain customer information, internal financial information, intellectual property, credentials, or regulated data.

Then there's the system prompt.

That may contain business rules, security instructions, application logic, or information about how internal systems work.

Then the AI retrieves context.

Maybe customer records.

Contracts.

Invoices.

Support tickets.

Employee information.

Database results.

Then there are the tools.

Perhaps the AI executes a query.

Calls an API.

Looks up an order.

Creates a ticket.

Sends a message.

Updates a record.

And finally, there's the response.

That response might itself contain sensitive information.

Yet many organizations are concentrating primarily on securing the data source.

That's necessary.

But it isn't enough anymore.

We also need to secure and observe the journey the data takes through the AI system.

## The Database Security Didn't Fail
Imagine we do this properly.

We create a service principal for the AI application.

We follow least privilege.

We grant it access only to the data the application requires.

Authentication works.

Authorization works.

Every database security control does exactly what it was designed to do.

And the AI retrieves the data.

Now what?

The service principal tells us whether the application was authorized to retrieve that data.

It doesn't tell us which pieces of that data were placed into a model's context, what other information they were combined with, what the model inferred from them, what appeared in its response, or what an agent subsequently did because of that response.

The database did its job.

The security boundary moved.

## "But We're Logging the Prompts"
Good.

That's a start.

It also creates an entirely new problem.

Imagine someone submits this:

Summarize this customer's financial situation. Their SSN is 123-45-6789 and their account number is...
Your security control catches it.

Excellent.

The request is blocked before it reaches the model.

Your shiny new AI security architecture worked.

Then your logging system helpfully writes the entire rejected prompt into a database.

Congratulations.

You successfully prevented sensitive information from reaching the AI...

...and created a brand-new database containing the sensitive information.

We'll spend at least one article on that particular bit of fun.

Because "log everything" isn't a security strategy either.

## Then We Gave the AI Tools
Things become even more interesting when AI stops answering questions and starts actually doing things.

There's a massive difference between:

What's the balance on this customer's account?
and:

Credit this customer's account $5,000.
The first requires data access.

The second requires authority.

And that's where I think we're going to have some uncomfortable architectural conversations.

Because this:

AI → Generated SQL → Privileged Database Login

is not an architecture.

It's a future incident report.

The AI should be able to request an action.

The architecture should decide whether that action is permitted.

Those are very different things.

We're going to build both versions.

And then we're going to attack them.

## Yesterday's Safe AI May Not Be Today's Safe AI
There's another problem that doesn't get enough attention.

AI systems change.

Models change.

Prompts change.

Users change how they ask questions.

Retrieved data changes.

Applications acquire new tools.

Permissions expand.

Business rules change.

Security policies change.

And sometimes the company hires a new CISO who looks at something everyone has been doing for three years and says:

Absolutely not.

So passing a security review when an AI application launches isn't enough.

We need to know whether its behavior changes over time.

We'll look at several kinds of drift throughout this series:

Prompt drift
Context drift
Model drift
Policy drift
Tool-use drift
Data-access drift
Outcome drift

And, more importantly, we'll look at how to measure them.

Because every quarter, someone should be able to ask:

Is this AI system still behaving the way we intended?

And the answer probably shouldn't be:

"Maybe"

## So We're Going to Build It
This series isn't going to stop at architecture diagrams.

We're going to build a reference implementation.

I'm calling it the AI Interaction Audit Framework — AIAF.

We'll use SQL Server 2025 as the reference database and Python for the application code.

We'll also create a synthetic Sherpa of Data dataset containing customers, orders, employees, payments, support information, sensitive data, different security classifications, and enough intentionally dangerous information to make our experiments interesting.

And then we're going to give an AI access to it.

What could possibly go wrong?

Quite a lot, hopefully.

Because we're also going to deliberately attack the systems we build.

We'll let the AI attempt things it shouldn't.

We'll try prompt injection.

We'll attempt unauthorized data access.

We'll let an agent request dangerous actions.

We'll see what happens when security policies change.

We'll change models.

We'll change prompts.

We'll create drift.

Then we'll use the audit data we've collected to figure out what happened.

## Why Ollama?
For the reference implementation, I'll be using Ollama to run our AI models locally.

That's intentional.

I don't want the architecture we're building to depend on Azure, AWS, Google, or any particular commercial AI provider.

The point of this series isn't which AI platform you should buy.

It's what happens to your data once AI enters the picture.

Ollama gives us a convenient local environment where we can experiment, break things, change models, and concentrate on the architecture surrounding the AI.

But Ollama is not a requirement for AIAF.

Use whatever model and provider make sense for your organization.

In fact, that's going to be one of our design requirements:

AIAF should observe an AI interaction without depending on a particular LLM, model vendor, or hosting platform.
If replacing your model provider causes your auditing, authorization, validation, and data-loss controls to disappear, those controls probably weren't part of your architecture in the first place.

## One Important Disclaimer
AIAF isn't going to magically make AI secure.

It isn't a commercial security product.

It isn't a replacement for your existing security architecture.

And running some SQL scripts from GitHub isn't going to make the auditors shower you with affection.

AIAF is a reference architecture.

We're going to use it to explore patterns for securing, validating, observing, and auditing AI interactions with enterprise data.

Some controls will be deterministic.

Some will require semantic analysis.

Some will require humans.

Some will depend on technologies your organization already uses.

The goal isn't to build the One True AI Security Platform™.

The goal is to understand what controls actually need to exist.

## Keep the Receipts
There's a simple question behind this entire series.

Imagine something goes badly wrong with an AI application tomorrow.

Six months from now, can you reconstruct:

Who asked what?
What did the AI see?
What was it allowed to do?
What did it actually do?
What did it return?
Why did your architecture allow it?

And perhaps most importantly:

Can you prove it?

If you can't, we have some architecture to build.

Because we spent decades learning how to secure the database.

Then we connected an AI to it.

We probably ought to keep the receipts.
