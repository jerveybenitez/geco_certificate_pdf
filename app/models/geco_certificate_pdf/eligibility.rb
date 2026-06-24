module GecoCertificatePdf
  # just gets the student's completion status
  module Eligibility
    def self.completed?(course, user)
      return false unless course.context_modules.active.exists?

      CourseProgress.new(course, user).completed_at.present?
    end
  end
end
