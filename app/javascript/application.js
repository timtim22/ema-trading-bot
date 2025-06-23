// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import Rails from "@rails/ujs"
Rails.start()
window.Rails = Rails;
// import "chart" // Temporarily disabled to fix loading issues

import "controllers"
import "bootstrap"

console.log("application.js loaded")
