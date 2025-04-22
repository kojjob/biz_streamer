json.extract! profile, :id, :user_id, :username, :display_name, :bio, :profile_image, :created_at, :updated_at
json.url profile_url(profile, format: :json)
