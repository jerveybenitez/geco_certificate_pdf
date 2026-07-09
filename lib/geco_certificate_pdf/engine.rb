module GecoCertificatePdf
  class Engine < ::Rails::Engine
    initializer "geco_certificate_pdf.view_paths", after: :add_view_paths do |app|
      ActionController::Base.prepend_view_path(
        File.expand_path("../../app/views", __dir__)
      )
    end

    config.to_prepare do
      require_dependency GecoCertificatePdf::Engine.root.join("lib/geco_certificate_pdf/completion_hook.rb").to_s

      ContextModuleProgression.after_commit do |progression|
        GecoCertificatePdf::CompletionHook.check_and_issue(progression)
      end
    end
  end
end
