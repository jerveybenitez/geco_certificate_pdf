module GecoCertificatePdf
  class CertificateMailer < ActionMailer::Base
    default from: "noreply@upskilltoday.com"
    self.smtp_settings = (ActionMailer::Base.smtp_settings || {}).merge(
      open_timeout: 30,
      read_timeout: 60
    )
    def completion_email(user_id, course_id)
      user   = User.find(user_id)
      course = Course.find(course_id)

      progress = CourseProgress.new(course, user)
      return unless progress.completed_at.present?

      enrollment = course.enrollments.where(user: user, type: "StudentEnrollment").first
      return unless enrollment
      return if user.email.blank?

      pdf_bytes = GecoCertificatePdf::PdfGenerator.build(
        user, course, progress.completed_at, enrollment.created_at
      )

      attachments["certificate-#{course.id}.pdf"] = pdf_bytes

      @user_name    = user.name
      @course_name  = course.name

      mail(
        to: user.email,
        subject: "Congratulations on completing #{course.name}!"
      )
    end
  end
end