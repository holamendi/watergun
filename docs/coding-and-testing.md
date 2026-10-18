# Watergun coding and testing contract

Use the local exemplars, not a new framework:

- app/models/app/create_app.rb: plain namespaced ActiveModel service, save returns
  a boolean; Deployment::CreateDeployment#save! returns its record; destroy keeps
  its established result. AR records keep associations, encryption, validations,
  IDs, predicates and broadcasts. Remote workflow ownership stays in services.
- app/controllers/projects/apps_controller.rb and test/models/app/create_app_test.rb:
  direct service calls, local fixture/setup/describe/test language. Preserve Alba
  roots/allowlists and the installed Pagy behavior before inventing replacements.
- test/models/server_actions/create_app_test.rb and test_helpers/ssh_test_helper.rb:
  run the real action/service, mock external transport, assert literal commands
  and persisted product outcomes. Production command/status mappers are not an
  independent oracle. A fixture deliberately seeded successful is not execution.
- test/models/server_action_concurrency_test.rb: independent PostgreSQL sessions,
  distinct backend PIDs, deterministic lock barriers. Explain nontransactional
  tests, bound completion, join killed threads and clean only owned rows/jobs.
  Keep genuine commit, queue-insert and process-death tests where they prove an
  invariant. Do not build a generalized scenario DSL to hide status shortcuts.

Every guard needs one owner and an input/time boundary. HTTP owns untrusted shape;
locked mutation owns current editability/ancestry/admission; workers revalidate
execution authority. Prepared source identity is compared after locking without
repeating remote resolution under locks. Current is request/auth context, never
an execution collector/switch. Explicit run ownership transfers with enqueue:false;
ordinary services enqueue by default. No Result/bus/validator/context/AndSync layer.

Run the focused regression RED→GREEN while iterating; run the complete suite and
migrations/autoload/build/UI/JS/Alba/OpenAPI gates on the final candidate. Keep
Standard; config/environments/production.rb:49 has a preexisting STDOUT offense,
not permission for a blanket ignore or a full-tree-green claim.

## Narrow executable boundaries

    bundle exec archspec check --config Archspec.rb --format json
    bundle exec ruby script/check-style-boundaries .
    bundle exec ruby test/architecture/style_boundaries_test.rb

ArchSpec constrains App/EnvVariable/Deployment workflow references and the named
lifecycle service interfaces. It intentionally permits ApplicationRecord.transaction
and rich record behavior; no broad ApplicationRecord ban or generic preset.
Prism checks Current context declarations and direct constant-receiver table-wide
cleanup in files explicitly disabling transactions. Both have positive and
negative sabotage cases. They do not prove absence of dynamic dispatch, hidden
control inside allowed fields, inherited nontransactional tests, raw SQL/broad
relations, meaningful methods, truthful lifecycle or actual row ownership.

Do not evade a rule with renamed hidden state, dummy methods, file moves, dynamic
send, suppressions or TODO baselines. Review actual normal UI/API/webhook paths
against the exemplars. Structural checks complement behavior tests and complete-
diff human review; an agent PASS or green CI is not merge authorization.
