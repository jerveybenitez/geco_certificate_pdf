module GecoCertificatePdf
  module CompletionHook
    def self.check_and_issue(progression)
      return unless progression.workflow_state == "completed"

      user   = progression.user
      course = progression.context_module&.context
      return unless course.is_a?(Course)

      return if GecoCertificatePdf::CertificateIssuance.exists?(user_id: user.id, course_id: course.id)

      progress = CourseProgress.new(course, user)
      return unless progress.completed_at.present?

      GecoCertificatePdf::CertificateIssuance.create!(
        user_id:   user.id,
        course_id: course.id,
        issued_at: Time.zone.now
      )

      GecoCertificatePdf::CertificateMailer
        .completion_email(user.id, course.id)
        .deliver_later
    rescue ActiveRecord::RecordNotUnique
      # A parallel job already created the issuance for this pair —
      # the DB unique constraint caught it. Silently no-op; the "winning"
      # job already sent the email.
      nil
    rescue => e
      Rails.logger.error("[geco_certificate_pdf] Completion hook failed: #{e.message}")
    end
  end
end