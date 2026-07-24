# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "geco_certificate_pdf"
  spec.version       = "1.0.0"
  spec.authors       = ["JERVEY"]
  spec.summary       = "Adds a downloadable PDF completion certificate to Canvas courses"
  spec.files         = Dir["{app,config,lib}/**/*"]
  spec.require_paths = ["lib"]
  spec.add_dependency "prawn", "~> 2.4"
end
