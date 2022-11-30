# Introduction

The context is that fly.io’s approach of every framework uses a Dockerfile and a toml file is great for system administrators, polyglots, and Rails developers who are comfortable with Dockerfiles, or at least Debian. What that leaves behind is Rails developers who spend most of their time in an IDE on Macs or Windows; which frankly is most of them.

Many of these people would prefer to use buildpacks or some other method than Dockerfiles, and when they have problems with those approaches instead of reporting the problems to the maintainers of the buildpack they report the problem to us.

I’d prefer an approach where from a fly.io platform point of view everything is Dockerfiles and toml files and from a developer point of view everything is Rails and Ruby.

In order to run this make sure you have flyctl version v0.0.433 or later as I added a flag to allow dockerignore files to be provided at deploy time.

---

## Part one, a simple visitor counter

Start by creating a simple application and scaffold a visitor counter table:

```
rails new welcome --css tailwind
cd welcome
git add .
git commit -a -m 'initial commit'
bin/rails generate scaffold visitor counter:integer
bin/rails db:migrate
```

Modify the index method in the visitor controller to find the counter and increment it. 

Edit `app/controllers/visitors_controller.rb`:

```
  # GET /visitors or /visitors.json
  def index
    @visitor = Visitor.find_or_create_by(id: 1)
    @visitor.counter ||= 0
    @visitor.counter += 1
    @visitor.save!

    @visitor.update!(
      counter: (@visitor.counter || 0) + 1
    )
  end
```

Change the index view to show the fly.io balloon and the counter.

Replace `app/views/visitors/index.html.erb` with:

```html
<div class="absolute top-0 left-0 h-screen w-screen mx-auto mb-3 bg-navy px-20 py-14 rounded-[20vh] flex flex-row items-center justify-center" style="background-color:rgb(36 24 91)">
  <img src="https://fly.io/static/images/brand/brandmark-light.svg" class="h-[50vh]" style="margin-top: -15px" alt="The monochrome white Fly.io brandmark on a navy background" srcset="">

  <div class="text-white" style="font-size: 40vh; padding: 10vh" data-controller="counter">
    <%= @visitor.counter.to_i %>
  </div>
</div>
```

Define the root path to be the visitors index page:

Edit `config/routes.rb`:

```ruby
  # Defines the root path route ("/")
  root 'visitors#index'
```

Save our work so we can see what changed later.

```sh
git add .
git commit -m 'initial application'
```

Initial deployment:

```sh
bundle add fly.io-rails
bin/rails generate fly:app
bin/rails deploy
```

Note that a volume is created.  That's to store the sqlite3 database.  Making
that work actually takes multiple steps: create the volume, mount the volume, set an environment variable to cause rails to put the database on the mounted volume.

All of that is taken care of for you.

To see your app in production, run `fly open`.

---

## Part two: change the database

Edit `config/database.yml`:

```yaml
production:
  adapter: postgresql
```

Deploy your change:

```sh
bin/rails deploy
```

At this point, a `pg` gem is installed, a `postgres` database is created, and a
secret is set.  Also, there now is a separate release step that will run
your database migrations before restarting your server.

Again, all without you having to worry about anything.

---

## Part three: update the counter without requiring a refresh

```
bin/rails generate channel counter
```

Add `turbo_stream_from` and render the counter in a partial.

For this to work, make a partial that puts the counter into a turbo frame.

Create `app/views/visitors/_counter.html.erb`:

```
<%= turbo_frame_tag(dom_id visitor) do %>
  <%= visitor.counter.to_i %>
<% end %>
```

Update the view to add `turbo_stream_from` and render the partial.

Update `app/views/visitors/index.html.erb`:

```html
<%= turbo_stream_from 'counter' %>

<div class="absolute top-0 left-0 h-screen w-screen mx-auto mb-3 bg-navy px-20 py-14 rounded-[20vh] flex flex-row items-center justify-center" style="background-color:rgb(36 24 91)">
  <img src="https://fly.io/static/images/brand/brandmark-light.svg" class="h-[50vh]" style="margin-top: -15px" alt="The monochrome white Fly.io brandmark on a navy background" srcset="">

  <div class="text-white" style="font-size: 40vh; padding: 10vh" data-controller="counter">
    <%= render "counter", visitor: @visitor %>
  </div>
</div>
```

Add `broadcast_replace_later` to the controller:

Edit `app/controllers/visitors_controller.rb`:

```
  # GET /visitors or /visitors.json
  def index
    @visitor = Visitor.find_or_create_by(id: 1) 

    @visitor.update!(
      counter: (@visitor.counter || 0) + 1
    )

    @visitor.broadcast_replace_later_to 'counter', partial: 'visitors/counter'
  end
```

Deploy your change:

```sh
bin/rails deploy
```

At this point, a `redis` gem is installed (if it wasn't already), an upstash `redis` cluster is created if your organization didn't already have one (otherwise that cluster is reused), and a secret is set.

Once again, all without you having to worry about anything.

---

## Part four: change your cable adapter.

We've tried out two different databases.  Let's use an alternate cable implementation.

Modify `config/cable.yml`:

```yaml
production:
  adapter: any_cable
```

Deploy your change:

```sh
bin/rails deploy
```

Note that this time you are likely to see `502 Bad Gateway`.  That's because nginx typically starts faster than Rails and at this point this is just a demo.  Don't worry, Rails will start in a few seconds and things will work once it starts.  If you check the logs you will often see a similar problem where anycable go starts faster than anycable rpc, but that also corrects itself.

Once again, gems are installed and this time at runtime multiple processes are run, including one additional process (nginx) to transparently route the websocket to anycable.
All on a single 256MB fly machine.  The details are mess, but you don't have to worry about them.

---

## Recap

Run the following command to see what files were modified

```
git status
```

In addition to the `config` and `app` files that you modified you should see two files:
  * `config/fly.rb`
  * `fly.toml`

Both are relatively small, in fact `fly.toml` is only one line.  The other file is
likely to change dramatically so don't get too attached to it.  What it is meant to
describe is the deployment specific information that can't be gleaned from the
configuration files alone, things like machine and volume sizes.  The hope is that
it will cover replication and geographic placement of machines; conceptually similar
to what terraform provides today but expressed at a much higher level and in a
familiar Ruby syntax. 

If you want to see the configuration files that actually are used, run the following command:

```
bin/rails generate fly:app --eject
```

Note: this demo uses fly machines v2, and requires a script (`rails deploy`)
to build a dockerfile and run the underlying commands and APIs to create
machines, set secrets, etc.  It is possible to run with nomad (a.k.a. v1) by
passing `--nomad` on the `bin/rails generate fly:app` command, and while
this will allow you to run vanilla `fly deploy` the tradeoff is this
is accomplished by creating a `Dockerfile` and various other artifacts.
