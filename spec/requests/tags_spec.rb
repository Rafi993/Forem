require "rails_helper"

RSpec.describe "Tags", type: :request, proper_status: true do
  describe "GET /tags" do
    it "returns proper page" do
      get "/tags"
      expect(response.body).to include("Top 100 Tags")
    end
  end

  describe "GET /tags/search" do
    let(:authorized_user) { create(:user) }
    let(:mock_documents) do
      [{ "name" => "tag1" }, { "name" => "tag2" }, { "name" => "tag3" }]
    end

    it "returns json" do
      sign_in authorized_user
      allow(Search::Tag).to receive(:tag_search_documents).and_return(
        mock_documents,
      )
      get "/tags/search"
      expect(response.parsed_body).to eq("result" => mock_documents)
    end
  end

  describe "GET /t/:tag/edit" do
    let(:tag)                  { create(:tag) }
    let(:another_tag)          { create(:tag) }
    let(:unauthorized_user)    { create(:user) }
    let(:tag_moderator)        { create(:user) }
    let(:super_admin)          { create(:user, :super_admin) }

    it "does not allow not logged-in users" do
      get "/t/#{tag}/edit"
      expect(response).to redirect_to("/enter")
    end

    it "does not allow users who are not tag moderators" do
      sign_in unauthorized_user
      get "/t/#{tag}/edit"
      expect(response).to have_http_status(:not_found)
    end

    it "allows super admins" do
      sign_in super_admin
      get "/t/#{tag}/edit"
      expect(response.body).to include("Click here to see an example of attributes.")
    end

    context "when user is a tag moderator" do
      before do
        tag_moderator.add_role(:tag_moderator, tag)
        sign_in tag_moderator
      end

      it "allows authorized tag moderators" do
        get "/t/#{tag}/edit"
        expect(response.body).to include("Click here to see an example of attributes.")
      end

      it "does not allow moderators of one tag to edit another tag" do
        get "/t/#{another_tag}/edit"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "UPDATE /tags" do
    valid_params = { tag: { text_color_hex: "", bg_color_hex: "" } }
    let(:tag)                  { create(:tag) }
    let(:another_tag)          { create(:tag) }
    let(:unauthorized_user)    { create(:user) }
    let(:tag_moderator)        { create(:user) }
    let(:super_admin)          { create(:user, :super_admin) }

    it "does not allow not logged-in users" do
      patch "/tag/#{tag.id}"
      expect(response).to redirect_to("/enter")
    end

    it "does not allow unauthorized users" do
      sign_in unauthorized_user
      patch "/tag/#{tag.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "allows super admins" do
      sign_in super_admin
      patch "/tag/#{tag.id}", params: valid_params
      expect(response).to redirect_to("/t/#{tag}/edit")
    end

    context "when user is a tag moderator" do
      before do
        tag_moderator.add_role(:tag_moderator, tag)
        sign_in tag_moderator
      end

      it "allows authorized tag moderators to update a tag" do
        patch "/tag/#{tag.id}", params: valid_params
        expect(response).to redirect_to("/t/#{tag}/edit")
      end

      it "updates updated_at for tag" do
        tag.update_column(:updated_at, 2.weeks.ago)
        patch "/tag/#{tag.id}", params: valid_params
        expect(tag.reload.updated_at).to be > 1.minute.ago
      end

      it "displays proper error messages" do
        invalid_text_color_hex = "udjsadasfkdjsa"
        patch "/tag/#{tag.id}", params: {
          tag: { text_color_hex: invalid_text_color_hex, bg_color_hex: "" }
        }
        expect(response.body).to include("Text color hex is invalid")
      end

      it "does not allow moderators of one tag to edit another tag" do
        patch("/tag/#{another_tag.id}", params: valid_params)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
