Reproduction instructions:

```
rails new welcome --css tailwind
cd welcome
git commit -a -m 'initial commit'
bin/rails generate scaffold visitor counter:integer
bin/rails generate channel counter
bin/rails db:migrate
```

Edit `config/routes.rb`:

```diff
   # Defines the root path route ("/")
   # root "articles#index"
+  root 'visitors#index'
 end
```

Edit `app/controllers/visitors_controller.rb`:

```diff
   # GET /visitors or /visitors.json
   def index
-    @visitors = Visitor.all
+    @visitor = Visitor.find_or_create_by(id: 1) 
+
+    @visitor.update!(
+      counter: (@visitor.counter || 0) + (params[:count] || 1).to_i
+    )
+
+    @visitor.broadcast_replace_later_to 'counter', partial: 'visitors/counter'
   end
```

Replace `app/views/visitors/index.html.erb` with:

```
<%= turbo_stream_from 'counter' %>

<div class="absolute top-0 left-0 h-screen w-screen mx-auto mb-3 bg-navy px-20 py-14 rounded-[20vh] flex flex-row items-center justify-center" style="background-color:rgb(36 24 91)">
  <img src="https://fly.io/static/images/brand/brandmark-light.svg" class="h-[50vh]" style="margin-top: -15px" alt="The monochrome white Fly.io brandmark on a navy background" srcset="">

  <div class="text-white" style="font-size: 40vh; padding: 10vh" data-controller="counter">
    <%= render "counter", visitor: @visitor %>
  </div>
</div>
```

Create `app/views/visitors/_counter.html.erb`:

```
<%= turbo_frame_tag(dom_id visitor) do %>
  <%= visitor.counter.to_i %>
<% end %>
```

Edit `app/channels/counter_channel.erb`:

```diff

 class CounterChannel < ApplicationCable::Channel
   def subscribed
-    # stream_from "some_channel"
+    stream_from "counter"
   end

   def unsubscribed
```
