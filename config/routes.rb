Rails.application.routes.draw do
  get "/courses/:course_id/certificate" => "geco_certificate_pdf/certificates#show",
      as: :geco_certificate_pdf_certificate
end
