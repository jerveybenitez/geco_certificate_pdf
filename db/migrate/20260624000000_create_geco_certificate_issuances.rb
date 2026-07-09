class CreateGecoCertificateIssuances < ActiveRecord::Migration[7.1]
  tag :predeploy

  def change
    create_table :geco_certificate_issuances do |t|
      t.bigint  :user_id,        null: false
      t.bigint  :course_id,      null: false
      t.datetime :issued_at,     null: false
      t.datetime :banner_shown_at

      t.timestamps
    end

    add_index :geco_certificate_issuances, [:user_id, :course_id], unique: true, name: "index_geco_cert_issuances_on_user_and_course"
  end
end
