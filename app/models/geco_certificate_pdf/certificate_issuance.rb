module GecoCertificatePdf
  class CertificateIssuance < GecoCertificatePdf::ApplicationRecord
    belongs_to :user, class_name: "::User"
    belongs_to :course, class_name: "::Course"

    def banner_pending?
      banner_shown_at.nil?
    end

    def mark_banner_shown!
      update_column(:banner_shown_at, Time.zone.now)
    end
  end
end