source "app/**/*.rb"

component :lifecycle_records, constants: %w[App EnvVariable Deployment]
component :lifecycle_services, in: ["app/models/app/*.rb", "app/models/deployment/*.rb", "app/models/env_variable/*.rb"]

lifecycle_records.cannot_reference_constants "ServerAction::Enqueue", "ServerAction::Accept",
  because: "Remote workflow ownership belongs in the existing namespaced plain services"
lifecycle_records.cannot_use :lifecycle_services,
  because: "Record methods and callbacks must not hide lifecycle dispatch"
lifecycle_services.must_implement_one_of :save, :save!, :destroy,
  because: "Keep Watergun's recognizable lifecycle service interfaces"
