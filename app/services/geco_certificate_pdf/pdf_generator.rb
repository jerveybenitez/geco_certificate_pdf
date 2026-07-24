require "prawn"

module GecoCertificatePdf
  class PdfGenerationError < StandardError; end

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

      assert_assets_exist!(template_path, font_path)

      completed_date = parse_date(@completed_at, field: "completed_at")
      enroll_date    = parse_date(@enroll_date, field: "enroll_date")

      start_date  = enroll_date.strftime("%B %-d, %Y")
      finish_date = completed_date.strftime("%B %-d, %Y")
      cert_number = "Cert # #{@course.course_code} #{completed_date.strftime('%Y-%m%d')}-#{@user.id}"

      user = @user
      course = @course

      begin
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
      rescue GecoCertificatePdf::PdfGenerationError
        raise
      rescue StandardError => e
        raise PdfGenerationError, "Failed to render certificate PDF: #{e.message}"
      end
    end

    private

    def assert_assets_exist!(template_path, font_path)
      unless File.exist?(template_path.to_s)
        raise PdfGenerationError, "Certificate template image not found at #{template_path}"
      end

      %w[Radley-Regular.ttf Radley-Italic.ttf].each do |font_file|
        full_path = font_path.join(font_file)
        unless File.exist?(full_path.to_s)
          raise PdfGenerationError, "Certificate font file not found at #{full_path}"
        end
      end
    end

    def parse_date(value, field:)
      case value
      when String
        begin
          Time.zone.parse(value) or raise ArgumentError, "unparseable date"
        rescue ArgumentError, TypeError => e
          raise PdfGenerationError, "Invalid #{field} value #{value.inspect}: #{e.message}"
        end
      when Time, Date, DateTime, ActiveSupport::TimeWithZone
        value
      when nil
        raise PdfGenerationError, "Missing required #{field} value"
      else
        raise PdfGenerationError, "Unsupported #{field} type #{value.class}: expected String, Time, or Date"
      end
    end
  end
end