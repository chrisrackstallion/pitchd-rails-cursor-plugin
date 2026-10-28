# index_app fixture

A Rails-shaped tree with one deliberate offence per cross-file cop, run end to
end by `spec/rubocop_config_spec.rb` through `bundle exec rubocop
--ignore-parent-exclusion` with `rubocop-harness-index.yml` inherited (the
flag stops the repo's own `fixtures/**` exclusion reaching in). It proves the runner builds the index,
hands it to the department, and that each cop's `Include` reaches the file it
should — the half a unit test on a single source string cannot cover.

Offences, by cop:

| Cop | File |
|-----|------|
| `AgentHarnessRails/RouteWithoutAction` | `config/routes.rb` — `resource :closure` without `module: :cards`; `edit` routed on a controller without it |
| `AgentHarnessRails/EnqueueOutsideCommit` | `app/models/concerns/publishable.rb` — `after_save :notify_later`, the method on `Article` |
| `AgentHarnessRails/ExecutedOutsideOwnSpec` | `spec/models/article_spec.rb` — runs `NotifySubscribersJob` |
| `AgentHarnessRails/MissingOwnSpec` | `app/models/concerns/publishable.rb`, `app/policies/article_policy.rb` |
| `AgentHarnessRails/MailerWithoutPreview` | `app/mailers/user_mailer.rb` — `receipt` has no preview |
| `AgentHarnessRails/MisfiledSpec` | `spec/models/account_onboarding_spec.rb` |
| `AgentHarnessRails/UnreferencedMethod` (run with `--only`) | `app/models/article.rb` — `legacy_slug`, and nothing else |

Excluded from the repo's own lint by `.rubocop.yml` and from the gem by the
gemspec, like `primitives_app/`.
