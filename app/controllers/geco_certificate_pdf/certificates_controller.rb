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
      Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: 36) do |pdf|
        accent = "273540" # matches the button color, rgb(39, 53, 64)

        # Outer border, right at the margin edge
        pdf.stroke_color accent
        pdf.line_width 2
        pdf.stroke_rectangle [0, pdf.bounds.height], pdf.bounds.width, pdf.bounds.height

        # Thin inner border for a classic "double frame" look
        inset = 10
        pdf.line_width 0.75
        pdf.stroke_rectangle [inset, pdf.bounds.height - inset],
                              pdf.bounds.width - (inset * 2),
                              pdf.bounds.height - (inset * 2)

        pdf.move_down 50

        pdf.fill_color accent
        pdf.font_size(14) { pdf.text "C E R T I F I C A T E   O F   C O M P L E T I O N", align: :center, style: :bold }

        pdf.move_down 10
        pdf.stroke_color accent
        pdf.line_width 1
        center_x = pdf.bounds.width / 2
        pdf.stroke_horizontal_line(center_x - 80, center_x + 80)

        pdf.move_down 40
        pdf.fill_color "000000"
        pdf.font_size(14) { pdf.text "This certifies that", align: :center, style: :italic }

        pdf.move_down 14
        pdf.fill_color accent
        pdf.font_size(30) { pdf.text user.name, align: :center, style: :bold }

        pdf.move_down 18
        pdf.fill_color "000000"
        pdf.font_size(14) { pdf.text "has successfully completed the course", align: :center, style: :italic }

        pdf.move_down 14
        pdf.fill_color accent
        pdf.font_size(22) { pdf.text course.name, align: :center, style: :bold }

        pdf.move_down 60
        pdf.fill_color "555555"
        pdf.font_size(12) do
          pdf.text "Completed on #{Time.zone.parse(completed_at).strftime('%B %-d, %Y')}", align: :center
        end
      end
    end

  end
end
