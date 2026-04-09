---
name: writing-services
description: >-
  Where application logic lives in Rails without an app/services layer —
  DHH/37signals style: rich models, concerns, model-namespaced POROs,
  ActiveModel form objects, and jobs. Use when deciding where behaviour
  belongs, or when the user mentions services, service objects, POROs, forms,
  jobs, operations, interactors, or use cases.
---

# Writing Services (The Rails Way)

<objective>
Rails has no service layer. Business logic belongs on models. When an operation
outgrows a single model method, extract to a PORO namespaced under the primary
model, a form object, or a job — never to `app/services/`. Follow DHH/37signals
conventions: rich domain models, minimal indirection, objects that represent
real concepts, and clarity over architecture astronautics.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| Deciding where logic lives | Read `references/patterns.md` § Decision Tree |
| Extracting a complex model method | Read `references/patterns.md` § POROs |
| Multi-model form | Read `references/patterns.md` § Form Objects |
| External API wrapper | Read `references/patterns.md` § External Integrations |
| Async processing | Read `references/patterns.md` § Jobs |
| Data import / export | Read `references/patterns.md` § Bulk Operations |
| Refactoring existing services | Read `references/patterns.md` § Migration Guide |
| Code review | Read all references, review against conventions |

### 2. The Decision Tree

Before writing any service-like object, walk this tree:

```
Does this logic operate on a single model instance?
├── YES → Model method (domain verb)
│         e.g. article.publish, account.suspend
└── NO
    Does it create/validate records from form input?
    ├── YES → Form object (ActiveModel::Model)
    │         e.g. Registration, Checkout, Import
    └── NO
        Is it async work, scheduled, or retriable?
        ├── YES → Job (ActiveJob)
        │         e.g. ProcessPaymentJob, SyncInventoryJob
        └── NO
            Is there a primary model this coordinates around?
            ├── YES → PORO namespaced under that model
            │         e.g. Account::Onboarding, Order::Fulfillment
            └── NO
                Is this a noun your business uses in everyday language
                (not a technical operation dressed as a noun)?
                ├── YES → Standalone PORO in app/models/
                │         e.g. Search, Broadcast, Import
                │         Fails the test: ReportGenerator, PaymentProcessor,
                │         UserAuthenticator (verb phrases or infra wrappers)
                └── NO
                    Let the controller orchestrate inline.
```

### 3. Object Structure

When you do extract an object, structure it like this:

```ruby
# app/models/order/fulfillment.rb
class Order::Fulfillment
  attr_reader :order

  def initialize(order)
    @order = order
  end

  def process(tracking_number:)
    order.transaction do
      order.update!(status: :shipped, tracking_number: tracking_number)
      order.line_items.each(&:mark_shipped!)
      order.create_shipment_event!(tracking_number: tracking_number)
    end
  end
end
```

Key principles:
- **Named as a noun** — the object *is* a concept, not an action
- **Initialised with its primary model** — not a bag of dependencies
- **Methods are domain verbs** — `process`, `complete`, `import`, not `call` or `execute`
- **Lives in `app/models/`** — namespaced under the primary model
- **No base class** — each object stands alone
- **Uses the model's transaction** — keeps data integrity with the aggregate

### 4. Decision Framework

Before writing code, ask these questions:

**"Do I actually need a new object?"**
- One model, one action → model method. Full stop.
- Two models, controller can coordinate → inline orchestration is fine
- Extract when you can name the concept precisely and the name is richer than the model
  name alone. If you're struggling to name it, the logic belongs on the model.

**"What should this object be called?"**
- Named after a domain noun, not a verb: `Onboarding`, not `OnboardService`
- Namespaced under the primary model: `Account::Onboarding`, not `OnboardAccount`
- If you can't find a good noun, the logic might belong on the model

**"Where does this file live?"**
- Form objects → `app/models/` (e.g. `app/models/registration.rb`)
- Model-namespaced POROs → `app/models/model_name/` (e.g. `app/models/order/fulfillment.rb`)
- Standalone domain objects → `app/models/` (e.g. `app/models/search.rb`)
- Jobs → `app/jobs/` (e.g. `app/jobs/process_payment_job.rb`)
- Never → `app/services/`

**"Is this a form object or a PORO?"**
- Receives user input, needs validation → form object (`ActiveModel::Model`)
- Receives model instances, performs operations → PORO
- Both → form object that delegates to model methods after validation

### 5. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| `app/services/` directory | `app/models/` — POROs live alongside models |
| `ApplicationService` base class | No base class — each object stands alone |
| Single-method `call` convention | Named domain verb (`process`, `complete`, `import`) |
| Service wrapping one `update!` | Model domain verb |
| Service objects injecting models to simulate loose coupling | If you need the model, be the model or live under it — PORO constructor injection is fine; injection-as-architectural-boundary is not |
| `ServiceResult` / `Result` monads | Return the created/updated record, or raise on failure |
| Service for validation | Form object (`ActiveModel::Model`) |
| Service for email | Mailer |
| Service for async work | Job |
| Service per CRUD action | Controller + model handle CRUD natively |
| God service coordinating everything | Break into model methods; controller orchestrates |
| `Interactor`, `UseCase`, `Command` patterns | POROs with domain names — no framework needed |
| `begin/rescue` in service for flow control | Let exceptions propagate; `rescue_from` in controller |

### 6. Naming Conventions

| Thing | Convention | Examples |
|-------|-----------|----------|
| POROs under models | Noun describing the operation | `Account::Onboarding`, `Order::Fulfillment` |
| Form objects | Noun describing the workflow | `Registration`, `Checkout`, `ContactForm` |
| Standalone domain objects | Domain noun | `Search`, `Broadcast`, `Import` |
| Methods | Domain verb | `process`, `complete`, `import`, `sync` |
| Jobs | `VerbNounJob` | `ProcessPaymentJob`, `SyncInventoryJob` |
| Exceptions | Namespaced under model | `Order::NotFulfillable`, `Account::AlreadySuspended` |

### 7. Verification

Before finishing, verify:

- [ ] No `app/services/` directory — objects live in `app/models/` or `app/jobs/`
- [ ] No `ApplicationService` or service base class
- [ ] No single-method `call` — methods use domain verbs
- [ ] Objects are named as nouns, not verb phrases
- [ ] POROs are namespaced under their primary model
- [ ] Form objects include `ActiveModel::Model` and have validations
- [ ] Async work is in jobs, not POROs
- [ ] Objects that wrap a single model call have been inlined to model methods
- [ ] Transactions wrap the right scope — ideally on the model's own `transaction`
- [ ] The object represents a real domain concept, not a procedural wrapper
- [ ] No result objects or monads — return records or raise exceptions

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
