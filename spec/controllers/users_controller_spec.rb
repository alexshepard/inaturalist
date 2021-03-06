require File.dirname(__FILE__) + '/../spec_helper'

describe UsersController, "dashboard" do
  before(:each) { enable_elastic_indexing(Update) }
  after(:each) { disable_elastic_indexing(Update) }
  it "should be accessible when signed in" do
    user = User.make!
    sign_in user
    get :dashboard
    expect(response).to be_success
  end
end

describe UsersController, "update" do
  let(:user) { User.make! }
  before { sign_in user }
  it "should allow you to change sharing preferences" do
    expect( user.prefers_share_observations_on_facebook ).to be true
    expect( user.prefers_share_observations_on_twitter ).to be true
    patch :update, id: user.id, user: {prefers_share_observations_on_facebook: "0", prefers_share_observations_on_twitter: "0"}
    user.reload
    expect( user.prefers_share_observations_on_facebook ).to be false
    expect( user.prefers_share_observations_on_twitter ).to be false
  end

  it "changes updated_at when changing preferred_project_addition_by" do
    expect {
      put :update, id: user.id, user: { preferred_photo_license: "CC-BY-NC-SA" }
      user.reload
    }.to_not change(user, :updated_at)
    expect {
      put :update, id: user.id, user: { preferred_project_addition_by: "none" }
      user.reload
    }.to change(user, :updated_at)
  end
end

describe UsersController, "delete" do
  it "should be possible for the user" do
    user = User.make!
    sign_in user
    without_delay { delete :destroy, :id => user.id }
    expect(response).to be_redirect
    expect(User.find_by_id(user.id)).to be_blank
  end
  
  it "should be impossible for everyone else" do
    user = User.make!
    nogoodnik = User.make!
    sign_in nogoodnik
    delete :destroy, :id => user.id
    expect(User.find_by_id(user.id)).not_to be_blank
  end
end

describe UsersController, "search" do
  it "should work while signed out" do
    get :search
    expect(response).to be_success
  end
end

describe UsersController, "set_spammer" do
  describe "non-curators" do
    it "cannot access it" do
      post :set_spammer
      expect(response).to be_redirect
      expect(flash[:alert]).to eq "You need to sign in or sign up before continuing."
    end
  end

  describe "curators" do
    before(:each) do
      @curator = make_curator
      http_login(@curator)
      request.env["HTTP_REFERER"] = "/"
    end

    it "can access it" do
      post :set_spammer
      expect(response).not_to be_redirect
      expect(flash[:alert]).to be_blank
    end

    it "can set spammer to true" do
      @user = User.make!(spammer: nil)
      post :set_spammer, id: @user.id, spammer: "true"
      @user.reload
      expect(@user.spammer).to be true
    end

    it "removes spam flags when setting to non-spammer" do
      @user = User.make!
      obs = Observation.make!(user: @user)
      @user.update_attributes(spammer: true)
      Flag.make!(flaggable: obs, flag: Flag::SPAM)
      expect(@user.spammer).to be true
      expect(@user.flags_on_spam_content.count).to eq 1
      post :set_spammer, id: @user.id, spammer: "false"
      @user.reload
      expect(@user.spammer).to be false
      expect(@user.flags_on_spam_content.count).to eq 0
    end

    it "resolves spam flags when setting to non-spammer" do
      o = Observation.make!
      f = Flag.make!(flaggable: o, flag: Flag::SPAM)
      expect( f ).not_to be_resolved
      post :set_spammer, id: o.user_id, spammer: "false"
      f.reload
      expect( f ).to be_resolved
    end

    it "does not resolve spam flags when setting to spammer" do
      o = Observation.make!
      f = Flag.make!(flaggable: o, flag: Flag::SPAM)
      expect( f ).not_to be_resolved
      post :set_spammer, id: o.user_id, spammer: "true"
      f.reload
      expect( f ).not_to be_resolved
    end

    it "leaves resolver blank when resolving flags" do
      o = Observation.make!
      f = Flag.make!(flaggable: o, flag: Flag::SPAM)
      expect( f ).not_to be_resolved
      post :set_spammer, id: o.user_id, spammer: "false"
      f.reload
      expect( f.resolver ).to be_blank
    end

  end
end

describe UsersController, "spam" do
  let(:spammer) { User.make!(spammer: true) }

  it "should render 403 when the user is a spammer" do
    get :show, id: spammer.id
    expect(response.response_code).to eq 403
  end
end
