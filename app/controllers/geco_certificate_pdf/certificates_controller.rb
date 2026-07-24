require "prawn"

module GecoCertificatePdf
  class CertificatesController < ApplicationController
    before_action :require_user

    def show
      @course = Course.find(params[:course_id])

      unless @course.enrollments.where(user: @current_user, type: "StudentEnrollment").exists?
        return render json: { error: "not_enrolled",
                               message: "You're not enrolled in this course as a student." },
                      status: :forbidden
      end

      unless @course.context_modules.active.exists?
        # blocked by default!
        return render json: { error: "no_modules",
                               message: "This course has no completion requirements set up yet, " \
                                        "so a certificate can't be issued automatically." },
                      status: :unprocessable_entity
      end

      progress = CourseProgress.new(@course, @current_user)

      unless progress.completed_at.present?
        return render json: { error: "not_completed",
                               message: "You haven't finished this course yet. " \
                                        "Complete all required module items first." },
                      status: :forbidden
      end

      enrolldate = @course.enrollments.where(user: @current_user, type: "StudentEnrollment").first.created_at

      begin
        pdf_bytes = GecoCertificatePdf::PdfGenerator.build(@current_user, @course, progress.completed_at, enrolldate)
      rescue GecoCertificatePdf::PdfGenerationError => e
        Rails.logger.error("[geco_certificate_pdf] #{e.message}")
        return render json: { error: "pdf_generation_failed",
                               message: "We couldn't generate your certificate. Please try again later." },
                      status: :internal_server_error
      end

      send_data pdf_bytes,
                filename: "certificate-#{@course.id}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

  end
end
