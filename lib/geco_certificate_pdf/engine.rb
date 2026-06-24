module GecoCertificatePdf
  class Engine < ::Rails::Engine
    # Deliberately not isolated — this plugin needs to read Canvas's own
    # Course, User, and Enrollment models directly (::Course, ::User, etc.)
    # rather than having its own namespaced model space.

    # Makes Rails check this plugin's app/views BEFORE Canvas core's own
    # app/views, for any template path that exists in both. This is how
    # app/views/courses/_course_show_secondary.html.erb in this plugin
    # "shadows" (fully replaces, not patches) Canvas's original partial of
    # the same name — without ever opening or editing the original file.
    #
    # Using ActionController::Base.prepend_view_path directly here instead
    # of mutating config.paths["app/views"] — the latter depends on this
    # initializer running before Rails finalizes the app's view-path order,
    # which isn't guaranteed. prepend_view_path is the documented, direct
    # way to insert a path at the front of the lookup chain regardless of
    # initializer ordering.
    initializer "geco_certificate_pdf.view_paths", after: :add_view_paths do
      views_path = File.expand_path("../../app/views", __dir__)
      ActiveSupport.on_load(:action_controller) do
        prepend_view_path(views_path)
      end
    end
  end
end
