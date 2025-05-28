# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# pin "chart", to: "chart.js" # Temporarily disabled

# ActionCable for real-time features
pin "@rails/actioncable", to: "actioncable.esm.js"

# Trading chart libraries
pin "lightweight-charts", to: "https://cdn.jsdelivr.net/npm/lightweight-charts@5.0.7/dist/lightweight-charts.standalone.production.js"

# Bootstrap
pin "bootstrap", to: "https://ga.jspm.io/npm:bootstrap@5.3.6/dist/js/bootstrap.esm.js"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js"
