# Task Routing Reference

## Agent → Model Mapping

| Agent | Model | Cost Profile |
|-------|-------|--------------|
| coding-agent | `deepseek-v4-pro` | 🔴 High quality — complex code generation |
| tester-agent | `deepseek-v4-pro` | 🔴 High quality — test design needs deep reasoning |
| planner-agent | `deepseek-v4-pro` | 🔴 High quality — architecture reasoning |
| doc-author-agent | `deepseek-v4-flash` | 🟢 Lightweight — text generation |
| product-manager-agent | `deepseek-v4-flash` | 🟢 Lightweight — business writing, requirements |

## Keyword-to-Agent Mapping

### coding-agent (model: `deepseek-v4-pro`)
implement, write code, build, create widget, add feature, fix bug, refactor, develop, code, function, class, method, API endpoint, route, screen, page, component, controller, provider, bloc, cubit, service, repository, model, DTO, helper, utility, migration, script, command

### tester-agent (model: `deepseek-v4-pro`)
test, unit test, widget test, integration test, coverage, mock, mockito, mocktail, assert, verify, expect, debug, bug fix, test failure, flaky, MissingPluginException, pumpAndSettle, finder, test doubles, fake, stub, spy, test coverage, regression

### doc-author-agent (model: `deepseek-v4-flash`)
document, docs, readme, PDF, DOCX, write doc, guide, manual, specification, report, export, print, changelog, release notes, API docs, user manual, setup guide, contributing, license, README, markdown, documentation site

### planner-agent (model: `deepseek-v4-pro`)
plan, architecture, design doc, schema, roadmap, sprint, timeline, milestone, structure, tech design, proposal, breakdown, epic, story points, estimation, dependency graph, system design, data flow, ERD, UML, sequence diagram, migration plan, rollback plan

### product-manager-agent (model: `deepseek-v4-flash`)
requirement, user story, feature request, PRD, scope, priorities, backlog, stakeholder, roadmap, product spec, acceptance criteria, MVP, OKR, KPI, business value, user research, A/B test, launch plan, go-to-market, competitive analysis

## Multi-Category Tasks

| Task Pattern | Route To (Model) | Then Route To (Model) |
|-------------|------------------|----------------------|
| Build feature + write tests | coding-agent (`deepseek-v4-pro`) | tester-agent (`deepseek-v4-pro`) |
| Plan feature + write PRD | product-manager-agent (`deepseek-v4-flash`) | planner-agent (`deepseek-v4-pro`) |
| Design architecture + document | planner-agent (`deepseek-v4-pro`) | doc-author-agent (`deepseek-v4-flash`) |
| Requirements + planning + coding | product-manager-agent → planner-agent (`deepseek-v4-flash` → `deepseek-v4-pro`) | coding-agent (`deepseek-v4-pro`) |
| Build + test + document | coding-agent (`deepseek-v4-pro`) | tester-agent (`deepseek-v4-pro`) → doc-author-agent (`deepseek-v4-flash`) |
