module GecoCertificatePdf
  module Eligibility
    def self.completed?(course, user)
      return false unless course.context_modules.active.exists?
      CourseProgress.new(course, user).completed_at.present?
    end

    def self.issuance_for(course, user)
      CertificateIssuance.find_by(course_id: course.id, user_id: user.id)
    end

    def self.pending_banner_for(course, user)
      issuance = issuance_for(course, user)
      return nil unless issuance&.banner_pending?
      issuance
    end
  end
end
