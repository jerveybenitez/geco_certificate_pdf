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
      pdf = build_pdf(@current_user, @course, progress.completed_at, enrolldate)

      send_data pdf.render,
                filename: "certificate-#{@course.id}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

    # make pdf file using prawn, check later how much we can customize
    def build_pdf(user, course, completed_at, enrolldate)
      template_path = GecoCertificatePdf::Engine.root.join(
        "app", "assets", "images", "cert_template.png"
      )

      completed_date = Time.zone.parse(completed_at)
      start_date = enrolldate.strftime("%B %-d, %Y") || "N/A"
      finish_date = completed_date.strftime("%B %-d, %Y")
      cert_number = "Cert # #{course.course_code} #{completed_date.strftime('%Y-%m%d')}"

      Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: 0) do |pdf|
        # background image
        pdf.image template_path.to_s, at: [0, pdf.bounds.top], width: pdf.bounds.width

        font_path = GecoCertificatePdf::Engine.root.join("app", "assets", "fonts")
        pdf.font_families.update(
          "Radley" => {
            normal: font_path.join("Radley-Regular.ttf").to_s,
            italic: font_path.join("Radley-Italic.ttf").to_s
          }
        )

        # student name
        pdf.font("Radley", style: :italic) do 
          pdf.formatted_text_box(
            [{ text: user.name, styles: [:underline], size: 36 }],
            at: [0, 310], width: 842, align: :center
          ) 
        end

        # course description + cert number
        blue = "2C4770"
        pdf.font("Radley") do 
          pdf.formatted_text_box(
            [
              { text: "Successful completion of an ", color: blue, size: 14 },
              { text: "instructor-led upskilling program", color: blue, size: 14, styles: [:underline] },
              { text: " titled,", color: blue, size: 14 }
            ],
            at: [0, 237], width: 842, align: :center
          )

          pdf.formatted_text_box(
            [
              { text: course.name, color: blue, size: 14, styles: [:underline] },
              { text: " conducted on ", color: blue, size: 14 },
              { text: start_date, color: blue, size: 14, styles: [:underline] },
              { text: " to ", color: blue, size: 14 },
              { text: finish_date, color: blue, size: 14, styles: [:underline] },
              { text: ".",  color: blue, size: 14 }
            ],
            at: [0, 220], width: 842, align: :center
          )
        end

        pdf.formatted_text_box(
          [{ text: cert_number, color: "888888", size: 11 }],
          at: [36, 28], width: 300
        )

      end
    end

  end
end
