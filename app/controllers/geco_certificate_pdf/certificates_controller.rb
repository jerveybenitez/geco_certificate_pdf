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

      pdf = build_pdf(@current_user, @course, progress.completed_at)

      send_data pdf.render,
                filename: "certificate-#{@course.id}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

    # make pdf file using prawn, check later how much we can customize
    def build_pdf(user, course, completed_at)
      Prawn::Document.new(page_size: "A4", page_layout: :landscape) do |pdf|
        pdf.font_size(28) { pdf.text "Certificate of Completion", align: :center }
        pdf.move_down 40
        pdf.font_size(18) { pdf.text "This certifies that", align: :center }
        pdf.move_down 10
        pdf.font_size(24) { pdf.text user.name, align: :center, style: :bold }
        pdf.move_down 10
        pdf.font_size(18) { pdf.text "has completed", align: :center }
        pdf.move_down 10
        pdf.font_size(22) { pdf.text course.name, align: :center, style: :bold }
        pdf.move_down 40
        pdf.font_size(12) { pdf.text "Completed on: #{Time.zone.parse(completed_at).strftime('%B %-d, %Y')}", align: :center }
      end
    end
  end
end
