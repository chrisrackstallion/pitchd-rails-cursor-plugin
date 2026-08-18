# Fixture app

A minimal, correct primitives tree and matching spec, used two ways:

- `spec/executables_spec.rb` runs `exe/rails-evals` against it as a subprocess,
  which is what covers the executable shim rather than the library behind it.
- CI runs the **packaged** executable against it, so a file missing from
  `spec.files` fails the build instead of someone else's first install.

It is checked in rather than scaffolded by heredoc in the workflow so the shape
is reviewable in a diff, and so both callers exercise the same tree.

Everything here is deliberately green. Failure cases belong in `spec/evals_spec.rb`,
where a fixture is built per example and the assertion says what it expects.
