require "prawn"

module GecoCertificatePdf
  class PdfGenerator
    def self.build(user, course, completed_at, enroll_date)
      new(user, course, completed_at, enroll_date).build
    end

    def initialize(user, course, completed_at, enroll_date)
      @user = user
      @course = course
      @completed_at = completed_at
      @enroll_date = enroll_date
    end

    def build
      template_path = GecoCertificatePdf::Engine.root.join("app", "assets", "images", "cert_template.png")
      font_path     = GecoCertificatePdf::Engine.root.join("app", "assets", "fonts")

      completed_date = @completed_at.is_a?(String) ? Time.zone.parse(@completed_at) : @completed_at
      start_date  = @enroll_date.strftime("%B %-d, %Y")
      finish_date = completed_date.strftime("%B %-d, %Y")
      cert_number = "Cert # #{@course.course_code} #{completed_date.strftime('%Y-%m%d')}-#{@user.id}"

      user = @user
      course = @course

      Prawn::Document.new(page_size: "A4", page_layout: :landscape, margin: 0) do |pdf|
        pdf.image template_path.to_s, at: [0, pdf.bounds.top], width: pdf.bounds.width

        pdf.font_families.update(
          "Radley" => {
            normal: font_path.join("Radley-Regular.ttf").to_s,
            italic: font_path.join("Radley-Italic.ttf").to_s
          }
        )

        pdf.font("Radley", style: :italic) do
          pdf.formatted_text_box(
            [{ text: user.name, size: 36 }],
            at: [0, 310], width: 842, align: :center
          )
        end

        blue = "2C4770"
        pdf.font("Radley") do
          pdf.formatted_text_box(
            [
              { text: "Successful completion of an ", color: blue, size: 14 },
              { text: "instructor-led upskilling program", color: blue, size: 14 },
              { text: " titled,", color: blue, size: 14 }
            ],
            at: [0, 237], width: 842, align: :center
          )

          pdf.formatted_text_box(
            [
              { text: course.name, color: blue, size: 14 },
              { text: " conducted on ", color: blue, size: 14 },
              { text: start_date, color: blue, size: 14 },
              { text: " to ", color: blue, size: 14 },
              { text: finish_date, color: blue, size: 14 },
              { text: ".", color: blue, size: 14 }
            ],
            at: [0, 220], width: 842, align: :center
          )
        end

        pdf.formatted_text_box(
          [{ text: cert_number, color: "888888", size: 11 }],
          at: [36, 28], width: 300
        )
      end.render
    end
  end
end