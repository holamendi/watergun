// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log('Vite ⚡️ Rails')

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log('Visit the guide for more information: ', 'https://vite-ruby.netlify.app/guide/rails')

// Example: Load Rails libraries in Vite.
//
import * as Turbo from '@hotwired/turbo-rails'

//
// import ActiveStorage from '@rails/activestorage'
// ActiveStorage.start()
//
// // Import all channels.
const channels = import.meta.glob('./**/*_channel.js')

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'
import { Application } from '@hotwired/stimulus'
import { registerControllers } from 'stimulus-vite-helpers'

const application = Application.start()

application.debug = true
window.Stimulus   = application

const controllers = import.meta.glob('~/controllers/*_controller.js', { eager: true })
registerControllers(application, controllers)

