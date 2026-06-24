# geco_certificate_pdf

A Canvas LMS plugin (Rails Engine) that generates a PDF completion
certificate, downloadable per-course per-student.

## Install (local dev or server)

1. Copy this whole `geco_certificate_pdf/` folder into your canvas-lms
   checkout at:

       canvas-lms/gems/plugins/geco_certificate_pdf/

2. From the canvas-lms root:

       bundle install

       For Docker:
         docker compose run --rm web bundle install
         docker compose exec web bin/spring stop
         docker compose restart web

   Bundler's `Gemfile.d/plugins.rb` automatically picks up
   `gems/plugins/geco_certificate_pdf/geco_certificate_pdf.gemspec` and adds it
   to the bundle as a local, path-based gem. No entry in Canvas's own
   `Gemfile` is needed.

3. Restart the Rails server (and Puma/Passenger if running standalone).
   No `db:migrate` step is needed for this version — it has no migrations.
   If you later add a `db/migrate/` folder to this plugin, it gets picked
   up by `rails db:migrate` automatically the same way.

4. Test it directly by visiting, while logged in as an enrolled user:

       https://your-canvas-domain/courses/<course_id>/certificate

## A routing gotcha worth understanding (not just copying)

`config/routes.rb` draws directly into `Rails.application.routes`, **not**
`GecoCertificatePdf::Engine.routes`. This distinction matters and is easy to
get backwards:

- `SomeEngine.routes.draw do ... end` creates routes inside a route set that
  belongs *only to the engine*. For those routes to actually become
  reachable by the running app, something needs to explicitly mount that
  engine's route set into the host app (`mount SomeEngine::Engine => "/"`)
  — the standard pattern for *isolated* engines (`rails plugin new --mountable`).
- `Rails.application.routes.draw do ... end` draws directly into the
  application's own live route set. No mount step needed, no separate
  route set to lose track of.

We deliberately chose the non-isolated style for this plugin (so models
like `Course`/`User` are referenced directly, not namespaced away), and a
non-isolated engine with no mount step needs the *second* form. The first
form compiles fine, the file gets found and evaluated without error, but
the resulting routes silently never show up in `rails routes` and 404 at
request time — there's no error message pointing at the mismatch, which is
what made this one take a while to track down.

One side effect of drawing straight into the app's routes: the controller
reference needs the full namespaced path (`"geco_certificate_pdf/certificates#show"`),
since there's no implicit engine-scoped namespace doing that resolution for
us anymore.

## Deploying to your server

Since this lives entirely in its own directory, your stated workflow works
as-is:

    # on your machine
    git add gems/plugins/geco_certificate_pdf
    git commit -m "Add geco_certificate_pdf plugin"
    git push

    # on the server
    git pull
    bundle install
    sudo systemctl restart canvas

No core files are touched, so there's nothing to merge/rebase when you next
pull updates from upstream canvas-lms — the plugin folder just travels
alongside your fork.

## Surfacing a button in the UI (shadow view)

Rather than a JS injection step, this plugin "shadows" Canvas's own course
sidebar partial — `app/views/courses/_course_show_secondary.html.erb` — with
a full copy of that file living inside this plugin, at the same relative
path, with a "Download Certificate" button added right after the existing
"View Course Notifications" link.

This works because of the initializer in `lib/geco_certificate_pdf/engine.rb`:

```ruby
initializer "geco_certificate_pdf.view_paths" do |app|
  app.config.paths["app/views"].unshift(
    File.expand_path("../../app/views", __dir__)
  )
end
```

`unshift` puts this plugin's `app/views` at the *front* of Rails' view
lookup order, so when Canvas goes to render `courses/_course_show_secondary`,
it finds our copy first and never even looks at — let alone edits — the
original file in core. No merge conflicts on `git pull`.

**The real trade-off, stated plainly**: this is a full replacement, not a
patch. The copy currently in this plugin was taken from a Canvas instance
running Rails 8.0.5 (confirmed via `bundle show rails` against this specific
checkout). If Instructure changes `_course_show_secondary.html.erb` in a
later release — a bug fix, a new conditional block, a markup change — this
plugin will keep silently rendering the **old** version forever, because
Rails has no idea the two files are related. There's no warning when this
happens; it just quietly diverges.

**Practical mitigation**: before any Canvas upgrade, diff the upstream
`app/views/courses/_course_show_secondary.html.erb` against this plugin's
copy (minus the button block we added) to see what changed, and manually
re-apply those changes here. There's no way to automate this away — it's
the one ongoing maintenance cost of going this route instead of an LTI tool.

The button itself only shows for student enrollments (`@context_enrollment&.student?`,
the same guard already used by the existing "View Course Calendar" link
right above it). Clicking it calls the plugin's own
`/courses/:course_id/certificate` route via `fetch`, exactly like the
JS-injection version did previously — the only thing that changed is *how*
the button gets onto the page, not how it behaves once clicked.

The button also gets a `disabled` class and a custom background color
(`rgb(39, 53, 64)`, set inline so only this button is affected, not every
other `.btn.button-sidebar-wide` link on the page). Eligibility for the
`disabled` class is computed at render time by `GecoCertificatePdf::Eligibility.completed?`
(`app/models/geco_certificate_pdf/eligibility.rb`) — the same underlying
`CourseProgress` check the controller already enforces server-side, just
also exposed to the view so it can know the answer *before* the student
clicks. Clicking while ineligible short-circuits client-side with an alert,
instead of round-tripping to the server only to get the same answer back.

One thing worth knowing: this is now the **second** place that knows about
completion logic (the controller's checks, and this helper). They currently
agree because they're both reading from the same `CourseProgress`/`context_modules`
source, but if you ever change the eligibility rules, both spots need updating
— there's no single source of truth enforcing that they stay in sync.

## Notes / next steps you may want

- The completion check (student enrollment + `CourseProgress.completed_at`)
  lives in `GecoCertificatePdf::CertificatesController#show`. See the
  earlier caveat in this README's history: it's untested against a live
  Canvas instance, and courses with no modules at all currently get denied
  by default rather than allowed — revisit that if it doesn't match what
  you actually want.
- The PDF layout is intentionally bare — Prawn supports images (e.g. a
  school logo or signature) and custom fonts if you want to dress it up.

## Table naming convention (geco_ prefix)

Every model in this plugin should inherit from `GecoCertificatePdf::ApplicationRecord`
(`app/models/geco_certificate_pdf/application_record.rb`) instead of
`ActiveRecord::Base` directly. That base class sets:

```ruby
self.table_name_prefix = "geco_"
```

which means Rails automatically expects/infers a `geco_` prefixed table name
for any model under it — you don't have to remember to type the prefix on
every model. Example:

```ruby
# app/models/geco_certificate_pdf/certificate_issuance.rb
module GecoCertificatePdf
  class CertificateIssuance < GecoCertificatePdf::ApplicationRecord
  end
end
```

infers table `geco_certificate_issuances` automatically — no `self.table_name = ...`
needed on the model.

The one thing this *doesn't* do automatically: the migration that creates
the table still has to literally use the prefixed name, since
`table_name_prefix` only affects what the model expects to find, not what
gets created in the database:

```ruby
# db/migrate/20260623000000_create_geco_certificate_issuances.rb
class CreateGecoCertificateIssuances < ActiveRecord::Migration[7.1]
  def change
    create_table :geco_certificate_issuances do |t|
      t.references :user, null: false
      t.references :course, null: false
      t.timestamps
    end
  end
end
```

So the rule of thumb for any future migration in this plugin: the
`create_table` (or `add_column`, `create_join_table`, etc.) name should
start with `geco_`, and as long as the model inherits from
`GecoCertificatePdf::ApplicationRecord`, the two will line up without you
having to set anything explicitly on the model itself.
